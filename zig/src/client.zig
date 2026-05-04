const Monitor = @import("monitor.zig").Monitor;
const App = @import("app.zig").App;
const X = @import("c_lib.zig").X;
const Window = X.Window;
const fstr = @import("fstr.zig").fstr;
const Display = X.Display;
const Rect = @import("rect.zig").Rect;
const Atom = X.Atom;
const toggle = @import("toggle.zig").toggle;
const cfg = @import("config.zig");

const Size = struct {
    const Self = @This();

    /// Width.
    w: u32,
    /// Height.
    h: u32,

    pub inline fn eq(lhs: *const Self, rhs: *const Self) bool {
        return lhs.w == rhs.w and lhs.h == rhs.h;
    }
};

const ClientSizes = struct {
    base: ?Size = null,
    /// Incremental size when resizing.
    inc: ?Size = null,
    max: ?Size = null,
    min: ?Size = null,
    /// Maximum aspect ratio (width / height).
    maxa: ?f32 = null,
    /// Minimum aspect ratio (height / width).
    /// Note that this is the reciprocal of the conventional notion of the
    /// aspect ratio because of how we'll be using it.
    mina: ?f32 = null,
};

pub const Client = struct {
    const Self = @This();
    app: *const App,

    name: fstr(256) = undefined,
    /// Position, current and previous.
    pos: toggle(Rect),
    sz: ClientSizes = undefined,
    hintsvalid: bool = undefined,
    /// Border width.
    bw: toggle(i32),
    /// Bitmask of active tags.
    tags: u32 = 0,
    isfixed: bool = undefined,
    isfloating: toggle(bool),
    isurgent: bool = undefined,
    neverfocus: bool = undefined,
    isfullscreen: bool = undefined,
    /// Next client in the linked list of clients.
    next: ?*Self = null,
    /// Next client in the display stack.
    snext: ?*Self = null,
    mon: *Monitor = undefined,
    win: Window,

    pub fn init(app: *const App, w: Window, wa: *X.XWindowAttributes) Self {
        return Self{
            .app = app,
            .win = w,
            .pos = .init(.fromX(X.XWindowAttributes, wa)),
            .bw = .init(@intCast(wa.border_width)),
            .isfloating = .init(false),
        };
    }

    /// [dwm] updatetitle
    pub fn updateTitle(self: *Self) void {
        const z = self.app;
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
    pub fn setFocus(self: *Self) void {
        const z = self.app;
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
        _ = self.sendEvent(z.wmatom.get(.TakeFocus));
    }

    /// [dwm] sendevent
    /// Returns true upon successful execution.
    pub fn sendEvent(self: *Self, proto: Atom) bool {
        const z = self.app;
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
    pub inline fn width(self: *const Self) u32 {
        return self.pos.curr.w + 2 * @as(u32, @intCast(self.bw.curr));
    }

    /// [dwm] HEIGHT
    pub inline fn height(self: *const Self) u32 {
        return self.pos.curr.h + 2 * @as(u32, @intCast(self.bw.curr));
    }

    /// [dwm] configure
    pub fn configure(self: *const Self, dpy: ?*Display) void {
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
            @sizeOf(Atom),
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

    /// [dwm] setfullscreen
    pub fn setFullscreen(self: *Self, fullscreen: bool) void {
        const z = self.app;
        if (fullscreen and !self.isfullscreen) {
            _ = X.XChangeProperty(
                z.dpy,
                self.win,
                z.netatom.get(.WMState),
                X.XA_ATOM,
                32,
                X.PropModeReplace,
                @ptrCast(&z.netatom.get(.WMFullscreen)),
                1,
            );
            self.isfullscreen = true;
            self.bw.set(0);
            self.isfloating.set(true);
            self.resize(.{ .x = self.mon.mx, .y = self.mon.my, .w = self.mon.mw, .h = self.mon.mh });
            // XRaiseWindow(dpy, self.win);
        } else if (!fullscreen and self.isfullscreen) {
            _ = X.XChangeProperty(
                z.dpy,
                self.win,
                z.netatom.get(.WMState),
                X.XA_ATOM,
                32,
                X.PropModeReplace,
                null,
                0,
            );
            self.isfullscreen = false;
            self.isfloating.revert();
            self.bw.revert();
            self.pos.revert();
            self.resize(self.pos.curr);
            // arrange(self.mon);
        }
    }

    pub fn updateWindowType(self: *Self) void {
        const z = self.app;
        const net = z.netatom;
        if (self.getAtomProp(z.dpy, net.get(.WMState)) == net.get(.WMFullscreen)) {
            self.setFullscreen(true);
        }
        if (self.getAtomProp(z.dpy, net.get(.WMWindowType)) == net.get(.WMWindowTypeDialog)) {
            self.isfloating.set(true);
        }
    }

    /// [dwm] resizeclient
    /// Resize the X window, and also update its border width.
    pub fn resize(self: *Self, rect: Rect) void {
        const z = self.app;
        var wc = rect.toX(X.XWindowChanges);
        wc.border_width = self.bw.curr;
        const flags =
            X.CWX | X.CWY | X.CWWidth | X.CWHeight | X.CWBorderWidth;
        _ = X.XConfigureWindow(z.dpy, self.win, flags, &wc);
        self.pos.set(rect);
        self.configure(z.dpy);
        _ = X.XSync(z.dpy, X.False);
    }

    /// [dwm] resize
    pub fn hintAndResize() void {

        // if (applysizehints(c, &x, &y, &w, &h, interact)) {
        //     resizeclient(c, x, y, w, h);
        // }
    }

    /// [dwm] applysizehints
    /// Called during client window resize operations. `rect` is the originally
    /// suggested resize target. After applying size hints, `rect` will be
    /// updated to be a more correct resize target. Returns true if the final
    /// value of `rect` differs from the client's current state.
    pub fn applySizeHints(self: *Self, rect: *Rect, interact: bool) bool {
        const c: *const Self = self;
        const m: *Monitor = self.mon;

        // Set minimum possible.
        rect.w = @max(1, rect.w);
        rect.h = @max(1, rect.h);

        if (interact) {
            if (rect.x > c.app.sw) {
                // left-most point is beyond the limits of the current monitor.
                rect.x = @as(i32, @intCast(c.app.sw)) - @as(i32, @intCast(c.width()));
            }
            if (rect.y > c.app.sh) {
                // top-most point is beyond the limits of the current monitor.
                rect.y = @as(i32, @intCast(c.app.sh)) - @as(i32, @intCast(c.height()));
            }
            if (rect.x + @as(i32, @intCast(rect.w)) + 2 * c.bw.curr < 0) {
                rect.x = 0;
            }
            if (rect.y + @as(i32, @intCast(rect.h)) + 2 * c.bw.curr < 0) {
                rect.y = 0;
            }
        } else {
            if (rect.x >= m.wx + @as(i32, @intCast(m.ww))) {
                // if (*x >= m->wx + m->ww) *x = m->wx + m->ww - WIDTH(c);
                rect.x = m.wx + @as(i32, @intCast(m.ww)) - @as(i32, @intCast(c.width()));
            }
            if (rect.y >= m.wy + @as(i32, @intCast(m.wh))) {
                // if (*y >= m->wy + m->wh) *y = m->wy + m->wh - HEIGHT(c);
                rect.y = m.wy + @as(i32, @intCast(m.wh)) - @as(i32, @intCast(c.height()));
            }
            // if (rect.x >= m.wx + @as(i32, @intCast(m.ww))) {
            //     // if (*x + *w + 2 * c->bw <= m->wx) *x = m->wx;
            //     rect.x = m.wx + @as(i32, @intCast(m.ww)) - @as(i32, @intCast(c.width()));
            // }
            // if (rect.y >= m.wy + @as(i32, @intCast(m.wh))) {
            //     // if (*y + *h + 2 * c->bw <= m->wy) *y = m->wy;
            //     rect.y = m.wy + @as(i32, @intCast(m.wh)) - @as(i32, @intCast(c.height()));
            // }
        }

        if (rect.h < c.app.bar_height) rect.h = c.app.bar_height;
        if (rect.w < c.app.bar_height) rect.w = c.app.bar_height;

        if (cfg.resizehints or c.isfloating.curr or m.lt[m.sellt].arrange == null) {
            if (!c.hintsvalid) {
                self.updateSizeHints();
            }
            // dwm says: "see last two sentences in ICCCM 4.1.2.3".
            // Here is the entire last paragraph:
            // > The min_aspect and max_aspect fields are fractions with the
            // > numerator first and the denominator second, and they allow a
            // > client to specify the range of aspect ratios it prefers. Window
            // > managers that honor aspect ratios should take into account the
            // > base size in determining the preferred window size. If a base
            // > size is provided along with the aspect ratio fields, the base
            // > size should be subtracted from the window size prior to checking
            // > that the aspect ratio falls in range. If a base size is not
            // > provided, nothing should be subtracted from the window size.
            // > (The minimum size is not to be used in place of the base size
            // > for this purpose.)
            const baseismin = b: {
                const base = &(c.sz.base orelse break :b false);
                const min = &(c.sz.min orelse break :b false);
                break :b base.eq(min);
            };

            if (!baseismin) { // temporarily remove base dimensions
                if (c.sz.base) |*base| {
                    rect.w -= base.w;
                    rect.h -= base.h;
                }
            }

            { // adjust for aspect limits
                const w: f32 = @floatFromInt(rect.w);
                const h: f32 = @floatFromInt(rect.h);
                // If the aspect ratio is too large (very wide), then we reduce
                // the width to fix the ratio, and if the aspect ratio is too
                // small (very narrow), we reduce the height to make fix the
                // ratio. Both cases, we're making the window smaller.
                if (c.sz.mina) |mina| {
                    if (mina < h / w) {
                        rect.h = @intFromFloat(@as(f32, @floatFromInt(rect.w)) * mina + 0.5);
                    }
                }
                if (c.sz.maxa) |maxa| {
                    if (maxa < w / h) {
                        rect.w = @intFromFloat(@as(f32, @floatFromInt(rect.h)) * maxa + 0.5);
                    }
                }
            }
            if (baseismin) { // Increment calculation requires this.
                if (c.sz.base) |*base| {
                    rect.w -= base.w;
                    rect.h -= base.h;
                }
            }
            // Adjust for increment value.
            if (c.sz.inc) |inc| {
                rect.w -= rect.w % inc.w;
                rect.h -= rect.h % inc.h;
            }
            // Restore base dimensions.
            if (c.sz.base) |base| {
                rect.w += base.w;
                rect.h += base.h;
            }
            if (c.sz.min) |min| {
                rect.w = @max(rect.w, min.w);
                rect.h = @max(rect.h, min.h);
            }
            if (c.sz.max) |max| {
                rect.w = @min(rect.w, max.w);
                rect.h = @min(rect.h, max.h);
            }
        }
        return !c.pos.curr.eq(rect);
    }

    /// [dwm] updatesizehints
    pub fn updateSizeHints(self: *Self) void {
        var hint: X.XSizeHints = undefined;
        var msize: c_long = undefined;
        const sz: *ClientSizes = &self.sz;

        if (X.XGetWMNormalHints(self.app.dpy, self.win, &hint, &msize) == 0) {
            // Size is uninitialized, ensure that size.flags aren't used.
            hint.flags = X.PSize;
        }

        // [base]
        if (hint.flags & X.PBaseSize != 0) {
            sz.base = .{ .w = @intCast(hint.base_width), .h = @intCast(hint.base_height) };
        } else if ((hint.flags & X.PMinSize) != 0) {
            sz.base = .{ .w = @intCast(hint.min_width), .h = @intCast(hint.min_height) };
        } else sz.base = null;

        // [inc]
        if ((hint.flags & X.PResizeInc) != 0) {
            sz.inc = .{ .w = @intCast(hint.width_inc), .h = @intCast(hint.height_inc) };
        } else sz.inc = null;

        // [max]
        if ((hint.flags & X.PMaxSize) != 0) {
            sz.max = .{ .w = @intCast(hint.max_width), .h = @intCast(hint.max_height) };
        } else sz.max = null;

        // [min]
        if ((hint.flags & X.PMinSize) != 0) {
            sz.min = .{ .w = @intCast(hint.min_width), .h = @intCast(hint.min_height) };
        } else if ((hint.flags & X.PBaseSize) != 0) {
            sz.min = .{ .w = @intCast(hint.base_width), .h = @intCast(hint.base_height) };
        } else sz.min = null;

        if ((hint.flags & X.PAspect) != 0) {
            if (hint.min_aspect.y > 0) {
                sz.mina = @as(f32, @floatFromInt(hint.min_aspect.y)) / @as(f32, @floatFromInt(hint.min_aspect.x));
            }
            if (hint.max_aspect.y > 0) {
                sz.maxa = @as(f32, @floatFromInt(hint.max_aspect.x)) / @as(f32, @floatFromInt(hint.max_aspect.y));
            }
        } else {
            sz.mina = null;
            sz.maxa = null;
        }
        self.isfixed = isfixed: {
            const max = sz.max orelse break :isfixed false;
            const min = sz.min orelse break :isfixed false;
            break :isfixed max.eq(&min);
        };
        self.hintsvalid = true;
    }
};
