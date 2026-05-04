const Monitor = @import("monitor.zig").Monitor;
const App = @import("app.zig").App;
const X = @import("c_lib.zig").X;
const Window = X.Window;
const fstr = @import("fstr.zig").fstr;
const Display = X.Display;
const Rect = @import("rect.zig").Rect;

pub const Client = struct {
    const Self = @This();

    name: fstr(256) = undefined,
    mina: f32 = undefined,
    maxa: f32 = undefined,
    /// Currect position.
    r: Rect,
    /// Previous position.
    oldr: Rect,
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
    bw: i32 = undefined,
    /// Old border width.
    oldbw: i32 = undefined,
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
        const r = Rect.fromXWindowAttributes(wa);
        return Self{ .win = w, .r = r, .oldr = r };
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
    pub fn sendEvent(self: *Self, z: *App, proto: X.Atom) bool {
        var n: c_int = undefined;
        var protocols: ?[*]X.Atom = undefined;
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
};
