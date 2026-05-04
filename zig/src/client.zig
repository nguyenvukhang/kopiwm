const Monitor = @import("monitor.zig").Monitor;
const App = @import("app.zig").App;
const X = @import("c_lib.zig").X;
const Window = X.Window;
const fstr = @import("fstr.zig").fstr;
const Display = X.Display;
const Rect = @import("rect.zig").Rect;
const Atom = X.Atom;
const toggle = @import("toggle.zig").toggle;

pub const Client = struct {
    const Self = @This();

    name: fstr(256) = undefined,
    mina: f32 = undefined,
    maxa: f32 = undefined,
    /// Position, current and previous.
    pos: toggle(Rect),
    basew: i32 = undefined,
    baseh: i32 = undefined,
    incw: i32 = undefined,
    inch: i32 = undefined,
    maxw: i32 = undefined,
    maxh: i32 = undefined,
    minw: i32 = undefined,
    minh: i32 = undefined,
    hintsvalid: bool = undefined,
    /// Border width.
    bw: toggle(i32) = undefined,
    /// Bitmask of active tags.
    tags: u32 = 0,
    isfixed: bool = undefined,
    isfloating: bool = undefined,
    isurgent: bool = undefined,
    neverfocus: bool = undefined,
    /// Old floating state (previous value for `isfloating`).
    oldstate: bool = undefined,
    isfullscreen: bool = undefined,
    /// Next client in the linked list of clients.
    next: ?*Self = null,
    /// Next client in the display stack.
    snext: ?*Self = null,
    mon: *Monitor = undefined,
    win: Window,

    pub fn init(w: Window, wa: *X.XWindowAttributes) Self {
        return Self{
            .win = w,
            .pos = .init(.fromXWindowAttributes(wa)),
            .bw = .init(@intCast(wa.border_width)),
        };
    }

    /// [dwm] updatetitle
    pub fn updateTitle(self: *Self, z: *App) void {
        if (z.getTextProp(self.win, z.netatom.get(.WMName), &self.name.buffer)) |len| {
            self.name.len = len;
        } else if (z.getTextProp(self.win, X.XA_WM_NAME, &self.name.buffer)) |len| {
            self.name.len = len;
        } else {
            self.name.set("broken");
        }
    }

    /// [dwm] ISVISIBLE
    pub fn isVisible(self: *Self) bool {
        const m = self.mon;
        return self.tags & m.tagset[m.seltags] != 0;
    }

    /// [dwm] seturgent
    /// Sets the client's urgent state to `urgent`.
    pub fn setUrgent(self: *Self, dpy: ?*Display, urgent: bool) void {
        self.isurgent = urgent;
        var wmh: *X.XWMHints = X.XGetWMHints(dpy, self.win) orelse return;
        if (urgent) wmh.flags |= X.XUrgencyHint else wmh.flags &= ~X.XUrgencyHint;
        _ = X.XSetWMHints(dpy, self.win, wmh);
        _ = X.XFree(wmh);
    }

    /// Gets a pointer to the node in the linked list `self.mon.stack` that
    /// points to `self`.
    fn getStackPtr(self: *Self) ?*(?*Self) {
        var opt: *?*Self = &self.mon.stack;
        while (opt.*) |c| : (opt = &c.snext) {
            if (c == self) {
                return opt;
            }
        }
        return null;
    }

    /// [dwm] attach
    /// Puts `self` at the front of the Monitor's (self.mon) linked list.
    pub fn attach(self: *Self) void {
        self.next = self.mon.clients;
        self.mon.clients = self;
    }

    /// [dwm] attachstack
    /// Puts `self` at the front of the Monitor's (self.mon) linked list, but
    /// for the stack list.
    pub fn attachStack(self: *Self) void {
        self.snext = self.mon.stack;
        self.mon.stack = self;
    }

    /// [dwm] detachstack
    pub fn detachStack(self: *Self) void {
        if (self.getStackPtr()) |c| {
            c.* = self.snext;
        }

        if (self == self.mon.sel) {
            var opt = self.mon.stack;
            while (opt) |c| : (opt = c.snext) {
                if (c.isVisible()) {
                    self.mon.sel = c;
                    break;
                }
            }
        }
    }

    /// [dwm] setfocus
    pub fn setFocus(self: *Self, z: *App) void {
        if (!self.neverfocus) {
            _ = X.XSetInputFocus(z.dpy, self.win, X.RevertToPointerRoot, X.CurrentTime);
        }
        _ = X.XChangeProperty(
            z.dpy,
            z.root,
            z.netatom.get(.ActiveWindow),
            X.XA_WINDOW,
            32,
            X.PropModeReplace,
            @ptrCast(&self.win),
            1,
        );
        _ = self.sendEvent(z, z.wmatom.get(.TakeFocus));
    }

    /// [dwm] sendevent
    /// Returns true upon successful execution.
    pub fn sendEvent(self: *Self, z: *App, proto: Atom) bool {
        var n: c_int = undefined;
        var protocols: ?[*]Atom = undefined;
        var exists = false;

        if (X.XGetWMProtocols(z.dpy, self.win, &protocols, &n) != 0) {
            while (!exists and n > 0) {
                n -= 1;
                exists = protocols.?[@intCast(n)] == proto;
            }
            _ = X.XFree(@ptrCast(protocols));
        }
        if (exists) {
            var ev = X.XEvent{ .type = X.ClientMessage };
            ev.xclient = .{
                .window = self.win,
                .message_type = z.wmatom.get(.Protocols),
                .format = 32,
            };
            ev.xclient.data.l[0] = @intCast(proto);
            ev.xclient.data.l[1] = X.CurrentTime;
            _ = X.XSendEvent(z.dpy, self.win, X.False, X.NoEventMask, &ev);
        }
        return exists;
    }

    /// [dwm] WIDTH
    pub inline fn width(self: *Self) u32 {
        return self.pos.curr.w + 2 * @as(u32, @intCast(self.bw.curr));
    }

    /// [dwm] HEIGHT
    pub inline fn height(self: *Self) u32 {
        return self.pos.curr.h + 2 * @as(u32, @intCast(self.bw.curr));
    }

    /// [dwm] configure
    pub fn configure(self: *Self, dpy: ?*Display) void {
        const r = &self.pos.curr;
        var event = X.XEvent{
            .xconfigure = .{
                .type = X.ConfigureNotify,
                .display = dpy,
                .event = self.win,
                .window = self.win,
                .x = r.x,
                .y = r.y,
                .width = @intCast(r.w),
                .height = @intCast(r.h),
                .border_width = self.bw.curr,
                .above = X.None,
                .override_redirect = X.False,
            },
        };
        _ = X.XSendEvent(dpy, self.win, X.False, X.StructureNotifyMask, &event);
    }

    fn getAtomProp(self: *Self, dpy: ?*Display, prop: Atom) ?Atom {
        var da: Atom = undefined; // dummy atom.
        var atom: Atom = undefined;
        var format: c_int = undefined;
        var nitems: c_ulong = undefined;
        var dl: c_ulong = undefined; // dummy long.
        var property: ?[*]u8 = undefined;

        const res = X.XGetWindowProperty(
            dpy,
            self.win,
            prop,
            0,
            @sizeOf(atom),
            X.False,
            X.XA_ATOM,
            &da,
            &format,
            &nitems,
            &dl,
            &property,
        );
        if (res != X.Success) return null;
        defer _ = X.XFree(property);
        if (property) |p| {
            if (nitems > 0 and format == 32) {
                atom = @as([*]Atom, @ptrCast(@alignCast(p)))[0];
            }
        }
        return atom;
    }

    pub fn setFullscreen(self: *Self, z: *App, fullscreen: bool) void {
        if (fullscreen and !self.isfullscreen) {
            X.XChangeProperty(
                z.dpy,
                self.win,
                z.netatom.get(.WMState),
                X.XA_ATOM,
                32,
                X.PropModeReplace,
                @ptrCast(&z.netatom.get(.NetWMFullscreen)),
                1,
            );
            self.isfullscreen = true;
            self.oldstate = self.isfloating;
        }

        // if (fullscreen && !self.isfullscreen) {
        //     XChangeProperty(dpy, self.win, netatom[NetWMState], XA_ATOM, 32,
        //                     PropModeReplace,
        //                     (unsigned char *)&netatom[NetWMFullscreen], 1);
        //     self.isfullscreen = 1;
        //     self.oldstate = self.isfloating;
        //     self.oldbw = self.bw;
        //     self.bw = 0;
        //     self.isfloating = 1;
        //     resizeclient(c, self.mon->mx, self.mon->my, self.mon->mw, self.mon->mh);
        //     XRaiseWindow(dpy, self.win);
        // } else if (!fullscreen && self.isfullscreen) {
        //     XChangeProperty(dpy, self.win, netatom[NetWMState], XA_ATOM, 32,
        //                     PropModeReplace, (unsigned char *)0, 0);
        //     self.isfullscreen = 0;
        //     self.isfloating = self.oldstate;
        //     self.bw = self.oldbw;
        //     self.x = self.oldx;
        //     self.y = self.oldy;
        //     self.w = self.oldw;
        //     self.h = self.oldh;
        //     resizeclient(c, self.x, self.y, self.w, self.h);
        //     arrange(self.mon);
        // }

    }

    pub fn updateWindowType(self: *Self, z: *App) void {
        const net = z.netatom.get;
        if (self.getAtomProp(net(.WMState)) == net(.WMFullscreen)) {
            self.setFullscreen(z, true);
        }
        if (self.getAtomProp(net(.WMWindowType)) == net(.WMWindowTypeDialog)) {
            self.isfloating = true;
        }
    }
};
