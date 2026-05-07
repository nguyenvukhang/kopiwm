const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const log = std.log;
const dwmz = @import("app.zig");
const drw = @import("drw.zig").drw;
const cfg = @import("config.zig");
const Allocator = std.mem.Allocator;
const Monitor = @import("monitor.zig").Monitor;
const Client = @import("client.zig").Client;
const WM = @import("enums.zig").WM;
const Direction = @import("lazy_fn.zig").Direction;
const Layout = @import("layout.zig").Layout;
const Clk = @import("enums.zig").Clk;
const Arg = @import("lazy_fn.zig").Arg;
const Net = @import("enums.zig").Net;
const Rect = @import("rect.zig").Rect;
const SchemeState = @import("enums.zig").SchemeState;
const ColorScheme = @import("drw.zig").ColorScheme;
const N = @import("enums.zig").N;
const ForkError = std.posix.ForkError;
const MOUSEMASK = @import("config.zig").MOUSEMASK;
const DwmError = @import("errors.zig").DwmError;
const HandlerFn = @import("enums.zig").HandlerFn;

const NAME = @import("build_opts").name;
const VERSION = @import("build_opts").version;

const line = "----------------------------------------------------------------------";

// This exists because of config callbacks.
var global_allocator: Allocator = undefined;

// X11 stuff.
const X = @import("c_lib.zig").X;
const C = @import("c_lib.zig").C;
const Window = X.Window;
const Display = X.Display;
const XErrorEvent = X.XErrorEvent;
const XEvent = X.XEvent;

var z: dwmz.App = .init();

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = @import("logger.zig").customLog,
};

pub const QuickWrite = struct {
    const Self = @This();
    const Writer = std.Io.Writer;

    writer: *Writer,

    fn print(self: *Self, comptime fmt: []const u8, args: anytype) Writer.Error!void {
        try self.writer.print(fmt, args);
        try self.writer.flush();
    }

    pub fn init(writer: *Writer) Self {
        return .{ .writer = writer };
    }
};

/// (dwm) CLEANMASK
fn CLEANMASK(mask: u32) u32 {
    return (mask & ~(z.numlockmask | X.LockMask)) &
        (X.ShiftMask | X.ControlMask | X.Mod1Mask | X.Mod2Mask | X.Mod3Mask | X.Mod4Mask | X.Mod5Mask);
}

fn xerrordummy(_: ?*Display, _: [*c]XErrorEvent) callconv(.c) c_int {
    return 0;
}

/// (dwm) xerrorstart
fn xerrorstart(_dpy: ?*Display, _event: [*c]XErrorEvent) callconv(.c) c_int {
    _ = _dpy;
    _ = _event;
    std.debug.print(NAME ++ ": another window manager is already running\n", .{});
    std.process.exit(1);
}

/// (dwm) xerror
fn xerror(_dpy: ?*Display, err_event: [*c]XErrorEvent) callconv(.c) c_int {
    _ = _dpy;
    if (err_event == null) {
        std.debug.print(NAME ++ ": called xerror with null XErrorEvent value\n", .{});
        if (xerrorlib) |f| {
            return f(z.dpy, err_event);
        }
        @panic("xerror called but xerrorlib not defined yet.");
    }
    const e = err_event.*;
    const rc = e.request_code;
    const ec = e.error_code;
    if (ec == X.BadWindow or
        (rc == X.X_SetInputFocus and ec == X.BadMatch) or
        (rc == X.X_PolyText8 and ec == X.BadDrawable) or
        (rc == X.X_PolyFillRectangle and ec == X.BadDrawable) or
        (rc == X.X_PolySegment and ec == X.BadDrawable) or
        (rc == X.X_ConfigureWindow and ec == X.BadMatch) or
        (rc == X.X_GrabButton and ec == X.BadAccess) or
        (rc == X.X_GrabKey and ec == X.BadAccess) or
        (rc == X.X_CopyArea and ec == X.BadDrawable))
    {
        return 0;
    }
    std.debug.print(NAME ++ ": fatal error: request code={d}, error code={d}\n", .{ rc, ec });
    if (xerrorlib) |f| {
        return f(z.dpy, err_event);
    }
    @panic("xerror called but xerrorlib not defined yet.");
}

var xerrorlib: ?*const fn (?*Display, [*c]XErrorEvent) callconv(.c) c_int = null;

/// (dwm) checkotherwm
fn check_other_wm() void {
    xerrorlib = X.XSetErrorHandler(xerrorstart);
    // this causes an error if some other window manager is running
    _ = X.XSelectInput(z.dpy, X.DefaultRootWindow(z.dpy), X.SubstructureRedirectMask);
    _ = X.XSync(z.dpy, X.False);
    _ = X.XSetErrorHandler(xerror);
    _ = X.XSync(z.dpy, X.False);
}

/// (dwm) dirtomon
/// TODO: See if we can guarantee a non-null pointer.
fn directionToMonitor(direction: Direction) ?*Monitor {
    var m_opt: ?*Monitor = null;
    switch (direction) {
        .Next => {
            m_opt = if (z.selmon.next) |t| t else z.mons;
        },
        .Prev => {
            m_opt = z.mons;
            if (z.selmon == z.mons) {
                while (m_opt) |m| : (m_opt = m.next) {}
            } else {
                while (m_opt) |m| : (m_opt = m.next) {
                    if (m.next == z.selmon) {
                        break;
                    }
                }
            }
        },
    }
    return m_opt;
}

/// (dwm) focusmon
pub fn focusMon(arg: *const Arg) void {
    // Skip base case where there are no monitors to change focus to.
    // TODO: see if we can guarantee that `z.mons` is non-null.
    const mons = z.mons orelse return;
    if (mons.next == null) return;
    const m_opt = directionToMonitor(arg.d);
    if (m_opt == z.selmon) return;
    if (m_opt) |m| {
        unfocus(z.selmon.sel, false);
        z.selmon = m;
        focus(global_allocator, null);
    }
}

/// (dwm) focusstack
pub fn focusStack(arg: *const Arg) void {
    const sel = z.selmon.sel orelse return;
    if (sel.isfullscreen and cfg.lockfullscreen) return;
    var c_opt: ?*Client = null;
    switch (arg.d) {
        .Next => {
            c_opt = sel.next;
            // TODO: figure out why this isn't c.snext.
            while (c_opt) |c| : (c_opt = c.next) {
                if (c.isVisible()) {
                    break;
                }
            }
            if (c_opt == null) {
                c_opt = z.selmon.clients;
                while (c_opt) |c| : (c_opt = c.next) {
                    if (c.isVisible()) {
                        break;
                    }
                }
            }
        },
        .Prev => {
            var i_opt: ?*Client = null;
            i_opt = z.selmon.clients;
            while (i_opt) |i| : (i_opt = i.next) {
                if (i == sel) break;
                if (i.isVisible()) c_opt = i;
            }
            if (c_opt == null) {
                while (i_opt) |i| : (i_opt = i.next) {
                    if (i.isVisible()) c_opt = i;
                }
            }
        },
    }
    if (c_opt) |c| {
        focus(global_allocator, c);
        restack(global_allocator, z.selmon);
    }
}

/// (dwm) updatebarpos
fn updateBarPosition(m: *Monitor) void {
    m.w.y = m.m.y;
    m.w.h = m.m.h;
    if (m.show_bar) {
        m.w.h -= z.bar_height;
        m.by = switch (m.bar_pos) {
            .top => m.w.y,
            .bottom => m.w.b(),
        };
        m.w.y = switch (m.bar_pos) {
            .top => m.w.y + @as(i32, @intCast(z.bar_height)),
            .bottom => m.w.y,
        };
    } else {
        m.by = -@as(i32, @intCast(z.bar_height));
    }
}

/// (dwm) INTERSECT
fn intersect(x: i32, y: i32, w: i32, h: i32, m: *Monitor) i32 {
    return @max(0, @min(x + w, m.wx + @as(i32, @intCast(m.ww))) - @max(x, m.wx)) *
        @max(0, @min(y + h, m.wy + @as(i32, @intCast(m.wh))) - @max(y, m.wy));
}

/// (dwm) wintoclient
/// Searches all the monitors and all of their clients for one that matches
/// the window search query. Returns the first hit.
fn winToClient(w: Window) ?*Client {
    var m_opt = z.mons;
    var c_opt: ?*Client = null;
    while (m_opt) |m| : (m_opt = m.next) {
        c_opt = m.clients;
        while (c_opt) |c| : (c_opt = c.next) {
            if (c.win == w) return c;
        }
    }
    return null;
}

/// (dwm) getstate
fn getState(w: Window) i32 {
    var real: X.Atom = undefined;
    var format: c_int = undefined;
    var n: c_ulong = undefined;
    var extra: c_ulong = undefined;
    var property: ?[*]u8 = undefined;
    var result: i32 = -1;

    const res = X.XGetWindowProperty(
        z.dpy,
        w,
        z.wmatom.get(.State),
        0, // long_offset: Specifies the offset in the specified property (in 32-bit quantities) where the data is to be retrieved.
        2, // long_length: Specifies the length in 32-bit multiples of the data to be retrieved.
        X.False,
        z.wmatom.get(.State),
        &real,
        &format,
        &n,
        &extra,
        &property,
    );
    if (res != X.Success) return -1;
    defer _ = X.XFree(property);
    if (property) |p| {
        if (n != 0 and format == 32) {
            result = @as([*]i32, @ptrCast(@alignCast(p)))[0];
        }
    }
    return result;
}

/// (dwm) manage
fn manage(allocator: Allocator, w: Window, wa: *X.XWindowAttributes) error{OutOfMemory}!void {
    const c = try allocator.create(Client);
    c.* = .init(&z, w, wa);
    var trans: Window = X.None;
    var wc: X.XWindowChanges = undefined;
    // var t: *Client = undefined;

    c.updateTitle();
    blk: {
        if (X.XGetTransientForHint(z.dpy, w, &trans) != 0) {
            // This seems to make very little sense if there is a bijection between
            // clients and windows.
            if (winToClient(w)) |other_client| {
                c.tags = other_client.tags;
                c.mon = other_client.mon;
                break :blk;
            }
        }
        c.mon = z.selmon;
        c.applyRules();
    }
    if (X.XGetTransientForHint(z.dpy, w, &trans) != 0) {}
    var r = &c.*.pos.now;

    // If client is too far right, shift it left.
    if (r.x + c.width() > c.mon.w.r()) {
        r.x = c.mon.w.r() - c.width();
    }
    // If client is too far down, shift it up.
    if (r.y + c.height() > c.mon.w.b()) {
        r.y = c.mon.w.b() - c.height();
    }
    r.x = @max(r.x, c.mon.w.x); // If client is too far left, truncate it.
    r.y = @max(r.y, c.mon.w.y); // If client is too far up, truncate it.
    c.bw.set(cfg.borderpx);

    wc.border_width = @intCast(c.bw.now);
    _ = X.XConfigureWindow(z.dpy, w, X.CWBorderWidth, &wc);
    _ = X.XSetWindowBorder(z.dpy, w, z.scheme.get(.Normal).border.pixel);

    c.configure(z.dpy); // propagates border_width, if size doesn't change
    c.updateWindowType();
    c.updateSizeHints();
    c.updateWMHints();

    _ = X.XSelectInput(z.dpy, w, X.EnterWindowMask | X.FocusChangeMask | X.PropertyChangeMask | X.StructureNotifyMask);

    grabbuttons(c, false);

    if (!c.is_floating.now) {
        c.is_floating = .init(trans != X.None or c.is_fixed);
    }
    if (c.is_floating.now) {
        _ = X.XRaiseWindow(z.dpy, c.win);
    }
    c.attach();
    c.attachStack();

    _ = X.XChangeProperty(
        z.dpy,
        z.root,
        z.netatom.get(.ClientList),
        X.XA_WINDOW,
        32,
        X.PropModeAppend,
        @ptrCast(&c.win),
        1,
    );
    _ = X.XMoveResizeWindow(
        z.dpy,
        c.win,
        c.pos.now.x + 2 * @as(i32, @intCast(z.s.w)),
        c.pos.now.y,
        c.pos.now.w,
        c.pos.now.h,
    ); // dwm: some windows require this.
    // me: I have no idea why. Looks like we're pushing the window off the screen.

    c.setState(X.NormalState);
    if (c.mon == z.selmon) {
        unfocus(c.mon.sel, false);
    }
    c.mon.sel = c;
    arrange(allocator, c.mon);
    _ = X.XMapWindow(z.dpy, c.win);
    focus(allocator, null);
}

/// (dwm) unmanage
/// Destroys a client and removes it from the monitor that owns it.
fn unmanage(allocator: Allocator, c: *Client, destroyed: bool) void {
    const m = c.mon;
    c.detach();
    c.detachStack();

    if (c.mon.stack != null) {
        @panic("stack should be null after detach");
    }

    if (!destroyed) {
        _ = X.XGrabServer(z.dpy); // dwm: Avoid race conditions.
        _ = X.XSetErrorHandler(xerrordummy);
        _ = X.XSelectInput(z.dpy, c.win, X.NoEventMask);
        var wc: X.XWindowChanges = .{ .border_width = @intCast(c.bw.prev) };
        _ = X.XConfigureWindow(z.dpy, c.win, X.CWBorderWidth, &wc); // restore border
        _ = X.XUngrabButton(z.dpy, X.AnyButton, X.AnyModifier, c.win);
        c.setState(X.WithdrawnState);
        _ = X.XSync(z.dpy, X.False);
        _ = X.XSetErrorHandler(xerror);
        _ = X.XUngrabServer(z.dpy);
    }
    allocator.destroy(c);
    focus(allocator, null);
    updateClientList();
    arrange(allocator, m);
}

/// (dwm) updateclientlist
/// Updates the ClientList property in the X server.
fn updateClientList() void {
    var m_opt = z.mons;
    var c_opt: ?*Client = undefined;
    // Delete the existing list.
    _ = X.XDeleteProperty(z.dpy, z.root, z.netatom.get(.ClientList));
    // Rebuild the list.
    while (m_opt) |m| : (m_opt = m.next) {
        c_opt = m.clients;
        while (c_opt) |c| : (c_opt = c.next) {
            _ = X.XChangeProperty(
                z.dpy,
                z.root,
                z.netatom.get(.ClientList),
                X.XA_WINDOW,
                32,
                X.PropModeAppend,
                @ptrCast(&c.win),
                1,
            );
        }
    }
}

/// (dwm) arrangemon
fn arrangeMon(m: *Monitor) void {
    m.layout_symbol = m.lt[m.sellt].symbol;
    if (m.lt[m.sellt].arrange) |f| f(m);
}

/// (dwm) restack
fn restack(allocator: Allocator, m: *Monitor) void {
    drawbar(allocator, m);

    const has_arrange = m.lt[m.sellt].arrange != null;

    const sel = m.sel orelse return;
    if (sel.is_floating.now or !has_arrange) {
        _ = X.XRaiseWindow(z.dpy, sel.win);
    }
    if (has_arrange) {
        var wc: X.XWindowChanges = .{
            .stack_mode = X.Below,
            .sibling = m.barwin,
        };
        var c_opt = m.stack;
        while (c_opt) |c| : (c_opt = c.snext) {
            if (!c.is_floating.now and c.isVisible()) {
                _ = X.XConfigureWindow(z.dpy, c.win, X.CWSibling | X.CWStackMode, &wc);
                wc.sibling = c.win;
            }
        }
    }

    _ = X.XSync(z.dpy, X.False);
    var ev: XEvent = undefined;
    while (X.XCheckMaskEvent(z.dpy, X.EnterWindowMask, &ev) != 0) {}
}

/// (dwm) arrange
fn arrange(allocator: Allocator, monitor: ?*Monitor) void {
    var m_opt: ?*Monitor = null;
    if (monitor) |m| {
        if (m.stack) |c| c.showHide();
    } else {
        m_opt = monitor;
        while (m_opt) |m| : (m_opt = m.next) {
            if (m.stack) |c| c.showHide();
        }
    }
    if (monitor) |m| {
        arrangeMon(m);
        restack(allocator, m);
    } else {
        m_opt = monitor;
        while (m_opt) |m| : (m_opt = m.next) {
            arrangeMon(m);
        }
    }
}

/// (dwm) buttonpress
fn buttonPress(allocator: Allocator, e: *XEvent) DwmError!void {
    log.info("Start buttonPress()", .{});
    const ev: X.XButtonPressedEvent = e.xbutton;
    var click: Clk = .RootWin;
    var arg: Arg = undefined;

    // Focus monitor if necessary.
    const m = wintomon(ev.window);
    if (m != z.selmon) {
        if (z.selmon.sel) |c| unfocus(c, true);
        z.selmon = m;
        focus(allocator, null);
    }

    // Locate the click, and populate the `click` variable.
    // This block searches for the click location in the bar window.
    if (ev.window == z.selmon.barwin) {
        var i: usize = 0;
        var x: u32 = 0;
        while (true) {
            x += z.TEXTW(allocator, cfg.tags[i].text);
            if (ev.x >= x) {
                i += 1;
                if (i < cfg.tags.len) continue;
            }
            break;
        }
        if (i < cfg.tags.len) {
            click = .TagBar;
            arg = .{ .ui = @as(u32, 1) << @intCast(i) };
        } else if (ev.x < x + z.TEXTW(allocator, z.selmon.layout_symbol)) {
            click = .LtSymbol;
        } else if (ev.x > z.selmon.w.w - z.TEXTW(allocator, z.stext.get()) + z.lrpad - 2) {
            click = .StatusText;
        } else {
            click = .WinTitle;
        }
    }
    // Locate the click, and populate the `click` variable.
    // This block searches for the click location in the client.
    if (winToClient(ev.window)) |c| {
        focus(allocator, c);
        restack(allocator, z.selmon);
        _ = X.XAllowEvents(z.dpy, X.ReplayPointer, X.CurrentTime);
        click = .ClientWin;
    }

    // Search the `buttons` map for a hit.
    for (&cfg.buttons) |*button| {
        if (button.click != click or button.button != ev.button) continue;
        if (CLEANMASK(button.mask) == CLEANMASK(ev.state)) {
            const arg2 = switch (click) {
                .TagBar => &arg,
                else => &button.lf.arg,
            };
            switch (button.lf.func) {
                .MightError => |f| try f(arg2),
                .NoError => |f| f(arg2),
            }
        }
    }
}

/// (dwm) clientmessage
fn clientMessage(e: *XEvent) void {
    log.info("Start clientMessage()", .{});
    const ev: X.XClientMessageEvent = e.xclient;
    var c: *Client = winToClient(ev.window) orelse return;

    if (ev.message_type == z.netatom.get(.WMState)) {
        const fs_atom = z.netatom.get(.WMFullscreen);
        if (ev.data.l[1] == fs_atom or ev.data.l[2] == fs_atom) {
            c.setFullscreen(switch (ev.data.l[0]) {
                1 => true, // _NET_WM_STATE_ADD
                2 => !c.isfullscreen, // _NET_WM_STATE_TOGGLE
                else => false,
            });
        }
    } else if (ev.message_type == z.netatom.get(.ActiveWindow)) {
        if (c != z.selmon.sel and c.isurgent) {
            c.setUrgent(z.dpy, true);
        }
    }
}

/// (dwm) configurerequest
fn configureRequest(e: *XEvent) void {
    log.info("Start configureRequest()", .{});
    const ev = e.xconfigurerequest;
    const vmask = ev.value_mask;

    if (winToClient(ev.window)) |c| {
        if (vmask & X.CWBorderWidth != 0) {
            c.bw.set(@intCast(ev.border_width));
        } else if (c.is_floating.now or z.selmon.lt[z.selmon.sellt].arrange == null) {
            const m = c.mon;
            if (vmask & X.CWX != 0) {
                c.pos.prev.x = c.pos.now.x;
                c.pos.now.x = m.m.x + ev.x;
            }
            if (vmask & X.CWY != 0) {
                c.pos.prev.y = c.pos.now.y;
                c.pos.now.y = m.m.y + ev.y;
            }
            if (vmask & X.CWWidth != 0) {
                c.pos.prev.w = c.pos.now.w;
                c.pos.now.w = @intCast(ev.width);
            }
            if (vmask & X.CWHeight != 0) {
                c.pos.prev.h = c.pos.now.h;
                c.pos.now.h = @intCast(ev.height);
            }
            if (c.pos.now.r() > m.m.r() and c.is_floating.now) {
                // Center in x-direction.
                c.pos.prev.x = c.pos.now.x;
                c.pos.now.x = m.m.x + (@divFloor(@as(i32, @intCast(m.m.w)), 2) - @divFloor(c.width(), 2));
            }
            if (c.pos.now.b() > m.m.b() and c.is_floating.now) {
                // Center in y-direction.
                c.pos.prev.y = c.pos.now.y;
                c.pos.now.y = m.m.y + (@divFloor(@as(i32, @intCast(m.m.h)), 2) - @divFloor(c.height(), 2));
            }
            if ((vmask & (X.CWX | X.CWY) != 0) and (vmask & (X.CWWidth | X.CWHeight)) == 0) {
                c.configure(z.dpy);
            }
            if (c.isVisible()) {
                const r = &c.pos.now;
                _ = X.XMoveResizeWindow(z.dpy, c.win, r.x, r.y, r.w, r.h);
            }
        } else {
            c.configure(z.dpy);
        }
    } else {
        var wc: X.XWindowChanges = .{
            .x = ev.x,
            .y = ev.y,
            .width = ev.width,
            .height = ev.height,
            .border_width = ev.border_width,
            .sibling = ev.above,
            .stack_mode = ev.detail,
        };
        _ = X.XConfigureWindow(z.dpy, ev.window, @intCast(vmask), &wc);
    }

    // if ((c = wintoclient(ev->window))) {
    _ = X.XSync(z.dpy, X.False);
}

/// (dwm) configurenotify
fn configureNotify(allocator: Allocator, e: *XEvent) error{OutOfMemory}!void {
    log.info("Start configureNotify()", .{});
    const ev: X.XConfigureEvent = e.xconfigure;
    if (ev.window != z.root) return;
    const dirty = z.s.w != ev.width or z.s.h != ev.height;
    z.s.w = @intCast(ev.width);
    z.s.h = @intCast(ev.height);

    var selmon: ?*Monitor = z.selmon;
    // TODO: (dwm) updategeom handling sucks, needs to be simplified
    if ((try updategeom(allocator, &selmon)) or dirty) {
        z.drw.resize(z.s.w, z.bar_height);
        updateBars();
        var m_opt = z.mons;
        var c_opt: ?*Client = null;
        while (m_opt) |m| : (m_opt = m.next) {
            c_opt = m.clients;
            while (c_opt) |c| : (c_opt = c.next) {
                if (c.isfullscreen) {
                    c.resize(m.m);
                }
            }
            _ = X.XMoveResizeWindow(z.dpy, m.barwin, m.w.x, m.w.y, m.w.w, z.bar_height);
        }
        focus(allocator, null);
        arrange(allocator, null);
    }
}

/// (dwm) destroynotify
fn destroyNotify(allocator: Allocator, e: *XEvent) void {
    log.info("Start destroyNotify()", .{});
    const ev: X.XDestroyWindowEvent = e.xdestroywindow;
    if (winToClient(ev.window)) |c| unmanage(allocator, c, true);
}

/// (dwm) enternotify
fn enterNotify(allocator: Allocator, e: *XEvent) void {
    log.info("Start enterNotify()", .{});
    const ev: X.XCrossingEvent = e.xcrossing;
    if ((ev.mode != X.NotifyNormal or ev.detail == X.NotifyInferior) and ev.window != z.root) {
        return;
    }
    const c = winToClient(ev.window);
    const m = if (c) |client| client.mon else wintomon(ev.window);
    if (m != z.selmon) {
        unfocus(z.selmon.sel, true);
        z.selmon = m;
    } else if (c == null or c == z.selmon.sel) {
        return;
    }
    focus(allocator, c);
}

/// (dwm) expose
fn expose(allocator: Allocator, e: *XEvent) void {
    log.info("Start expose()", .{});
    const ev: X.XExposeEvent = e.xexpose;
    if (ev.count == 0) {
        drawbar(allocator, wintomon(ev.window));
    }
}

/// (dwm) focusin
fn focusIn(e: *XEvent) void {
    log.info("Start focusIn()", .{});
    const ev: X.XFocusChangeEvent = e.xfocus;
    if (z.selmon.sel) |sel| {
        if (ev.window != sel.win) sel.setFocus();
    }
}

/// (dwm) keypress
fn keyPress(e: *XEvent) DwmError!void {
    log.info("Start keyPress()", .{});
    const ev: X.XKeyEvent = e.xkey;
    const keysym = X.XkbKeycodeToKeysym(z.dpy, @intCast(ev.keycode), 0, 0);
    for (cfg.keys) |key| {
        if (keysym == key.sym and CLEANMASK(key.mod) == CLEANMASK(ev.state)) {
            switch (key.lf.func) {
                .MightError => |f| try f(&key.lf.arg),
                .NoError => |f| f(&key.lf.arg),
            }
        }
    }
}

/// (dwm) mappingnotify
fn mappingNotify(e: *XEvent) void {
    log.info("Start mappingNotify()", .{});
    const ev: *X.XMappingEvent = &e.xmapping;
    _ = X.XRefreshKeyboardMapping(ev);
    if (ev.request == X.MappingKeyboard) {
        grabkeys();
    }
}

/// (dwm) maprequest
fn mapRequest(allocator: Allocator, e: *XEvent) error{OutOfMemory}!void {
    log.info("Start mapRequest()", .{});
    const ev: X.XMapRequestEvent = e.xmaprequest;
    var wa: X.XWindowAttributes = undefined;

    const res = X.XGetWindowAttributes(z.dpy, ev.window, &wa);
    if (res == 0 or wa.override_redirect != 0) return;

    if (winToClient(ev.window) == null) {
        log.info("Start managing window {d} (maprequest)", .{ev.window});
        try manage(allocator, ev.window, &wa);
    }
}

/// (dwm) motionnotify
fn motionNotify(allocator: Allocator, e: *XEvent) void {
    const ev: X.XMotionEvent = e.xmotion;
    const static = struct {
        var mon: ?*Monitor = null;
    };
    if (ev.window != z.root) return;
    const rect = Rect{ .x = ev.x_root, .y = ev.y_root, .w = 1, .h = 1 };
    const m_opt = rect.toMonitor(z.selmon);
    if (m_opt) |m| {
        if (static.mon) |mon| {
            if (m != mon) {
                unfocus(z.selmon.sel, true);
                z.selmon = m;
                focus(allocator, null);
            }
        }
    }
    static.mon = m_opt;
}

/// (dwm) propertynotify
fn propertyNotify(allocator: Allocator, e: *XEvent) void {
    log.info("Start propertyNotify()", .{});
    const ev: X.XPropertyEvent = e.xproperty;
    if (ev.window == z.root and ev.atom == X.XA_WM_NAME) {
        updateStatus(allocator);
    } else if (ev.state == X.PropertyDelete) {
        return; // ignore.
    } else if (winToClient(ev.window)) |c| {
        switch (ev.atom) {
            X.XA_WM_TRANSIENT_FOR => {
                var trans: Window = undefined;
                const b = !c.is_floating.now and
                    X.XGetTransientForHint(z.dpy, c.win, &trans) != 0;
                c.is_floating.set(winToClient(trans) != null);
                if (b and c.is_floating.now) arrange(allocator, c.mon);
            },
            X.XA_WM_NORMAL_HINTS => c.hintsvalid = false,
            X.XA_WM_HINTS => {
                c.updateWMHints();
                drawbars(allocator);
            },
            else => {},
        }
        if (ev.atom == X.XA_WM_NAME or ev.atom == z.netatom.get(.WMName)) {
            c.updateTitle();
            if (c == c.mon.sel) {
                drawbar(allocator, c.mon);
            }
        }
        if (ev.atom == z.netatom.get(.WMWindowType)) {
            c.updateWindowType();
        }
    }
}

/// (dwm) unmapnotify
fn unmapNotify(allocator: Allocator, e: *XEvent) void {
    log.info("Start unmapNotify()", .{});
    const ev: X.XUnmapEvent = e.xunmap;
    if (winToClient(ev.window)) |c| {
        if (ev.send_event == 0) {
            unmanage(allocator, c, false);
        } else {
            c.setState(X.WithdrawnState);
        }
    }
}

/// For debugging: implement an emergency timeout in case we can't back out.
const TIMEOUT: bool = false;

/// (dwm) run
/// main event loop
fn run(allocator: Allocator) DwmError!void {
    _ = X.XSync(z.dpy, X.False);
    var ev: XEvent = undefined;
    const start = std.time.timestamp();

    while (z.running and X.XNextEvent(z.dpy, &ev) == X.Success) {
        if (TIMEOUT and @abs(std.time.timestamp() - start) > 20) @panic("End please");
        log.info("EVENT ----------------------------------------------------------------", .{});
        try runOne(allocator, &ev);
    }
}

inline fn runOne(allocator: Allocator, ev: *XEvent) DwmError!void {
    if (handler[@intCast(ev.type)]) |handler_fn| {
        switch (handler_fn) {
            .NoAllocE => |f| try f(ev),
            .AllocE => |f| try f(allocator, ev),
            .NoAlloc => |f| f(ev),
            .Alloc => |f| f(allocator, ev),
        }
    }
}

const handler: [X.LASTEvent]?HandlerFn = createHandler();
fn createHandler() [X.LASTEvent]?HandlerFn {
    var ret: [X.LASTEvent]?HandlerFn = undefined;
    var i: c_int = 0;
    while (i < ret.len) : (i += 1) {
        ret[@intCast(i)] = switch (i) {
            // zig fmt: off
            X.ButtonPress      => .{ .AllocE   = buttonPress },
            X.ClientMessage    => .{ .NoAlloc  = clientMessage },
            X.ConfigureNotify  => .{ .AllocE   = configureNotify },
            X.ConfigureRequest => .{ .NoAlloc  = configureRequest },
            X.DestroyNotify    => .{ .Alloc    = destroyNotify },
            X.EnterNotify      => .{ .Alloc    = enterNotify },
            X.Expose           => .{ .Alloc    = expose },
            X.FocusIn          => .{ .NoAlloc  = focusIn },
            X.KeyPress         => .{ .NoAllocE = keyPress },
            X.MapRequest       => .{ .AllocE   = mapRequest },
            X.MappingNotify    => .{ .NoAlloc  = mappingNotify },
            X.MotionNotify     => .{ .Alloc    = motionNotify },
            X.PropertyNotify   => .{ .Alloc    = propertyNotify },
            X.UnmapNotify      => .{ .Alloc    = unmapNotify },
            // zig fmt: on
            else => null,
        };
    }
    return ret;
}

/// (dwm) scan
fn scan(allocator: Allocator) error{OutOfMemory}!void {
    var wa: X.XWindowAttributes = undefined;
    var num: c_uint = undefined;
    var i: c_uint = undefined;
    var d1: Window = undefined;
    var d2: Window = undefined;
    var wins_opt: ?[*]Window = undefined;

    if (X.XQueryTree(z.dpy, z.root, &d1, &d2, &wins_opt, &num) == 0) {
        return;
    }
    // No need to call XFree because null in Zig means NULL in C.
    const wins: [*]Window = wins_opt orelse return;
    defer _ = X.XFree(wins);

    // Note: this section down here in important in deciding which window to be
    // `manage`d. We specifically do NOT want to be `manage`-ing the bar
    // window.

    i = 0;
    while (i < num) : (i += 1) {
        const res = X.XGetWindowAttributes(z.dpy, wins[i], &wa);
        if (res == 0 or wa.override_redirect != 0) continue;
        if (X.XGetTransientForHint(z.dpy, wins[i], &d1) != 0) continue;
        if (wa.map_state == X.IsViewable or getState(wins[i]) == X.IconicState) {
            log.info("Start managing window {d} (scan, non-transient)", .{wins[i]});
            try manage(allocator, wins[i], &wa);
        }
    }
    i = 0;
    while (i < num) : (i += 1) { // now the transients
        if (X.XGetWindowAttributes(z.dpy, wins[i], &wa) == 0) continue;
        if (X.XGetTransientForHint(z.dpy, wins[i], &d1) == 0) continue;
        const viewable = wa.map_state == X.IsViewable;
        const iconic = getState(wins[i]) == X.IconicState;
        if (viewable or iconic) {
            log.info("Start managing window {d} (scan, transient)", .{wins[i]});
            try manage(allocator, wins[i], &wa);
        }
    }
}

/// (dwm) incnmaster
pub fn incNMaster(arg: *const Arg) void {
    const i = switch (arg.*) {
        .i => |v| v,
        else => return,
    };
    z.selmon.nmaster = @intCast(@max(@as(i32, @intCast(z.selmon.nmaster)) + i, 0));
    arrange(global_allocator, z.selmon);
}

/// (dwm) killclient
pub fn killClient(_: *const Arg) void {
    const sel = z.selmon.sel orelse return;
    if (!sel.sendEvent(z.wmatom.get(.Delete))) {
        _ = X.XGrabServer(z.dpy);
        _ = X.XSetErrorHandler(xerrordummy);
        _ = X.XSetCloseDownMode(z.dpy, X.DestroyAll);
        _ = X.XKillClient(z.dpy, sel.win);
        _ = X.XSync(z.dpy, X.False);
        _ = X.XSetErrorHandler(xerror);
        _ = X.XUngrabServer(z.dpy);
    }
}

/// (dwm) monocle
pub fn monocle(m: *Monitor) void {
    var c_opt = m.clients;
    var n: u32 = 0;
    while (c_opt) |c| : (c_opt = c.next) {
        if (c.isVisible()) n += 1;
    }
    if (n > 0) { // Override layout symbol.
        // TODO: have to make the layout symbol an owned buffer. Right not it
        // can only display const strings.
        // snprintf(m->ltsymbol, sizeof m->ltsymbol, "[%d]", n);
    }
    c_opt = (c_opt orelse return).nextTiled();
    while (c_opt) |c| : (c_opt = c.nextTiled()) {
        var r = m.w;
        r.w = m.w.w - 2 * @as(u32, @intCast(c.bw.now));
        r.h = m.w.h - 2 * @as(u32, @intCast(c.bw.now));
        c.hintAndResize(r, false);
    }
}

/// (dwm) movemouse
pub fn moveMouse(_: *const Arg) DwmError!void {
    var c = z.selmon.sel orelse return;
    if (c.isfullscreen) return; // No support moving fullscreen windows by mouse.
    restack(global_allocator, z.selmon);

    // Old client x and y coordinates.
    const ocx = c.pos.now.x;
    const ocy = c.pos.now.y;

    const grab_res = X.XGrabPointer(
        z.dpy,
        z.root,
        X.False,
        MOUSEMASK,
        X.GrabModeAsync,
        X.GrabModeAsync,
        X.None,
        z.cursors.get(.Move),
        X.CurrentTime,
    );
    if (grab_res != X.GrabSuccess) return;
    var x: c_int = undefined;
    var y: c_int = undefined;
    if (!z.getRootPtr(&x, &y)) return;
    var ev: XEvent = undefined;
    var lasttime: X.Time = 0;
    while (true) {
        _ = X.XMaskEvent(z.dpy, MOUSEMASK | X.ExposureMask | X.SubstructureRedirectMask, &ev);
        switch (ev.type) {
            X.Expose | X.MapRequest | X.ConfigureRequest => try runOne(global_allocator, &ev),
            X.MotionNotify => {
                if (ev.xmotion.time - lasttime <= @divFloor(1000, cfg.refreshrate)) {
                    continue;
                }
                lasttime = ev.xmotion.time;
                var nx = ocx + (ev.xmotion.x - x);
                var ny = ocy + (ev.xmotion.y - y);
                if (@abs(z.selmon.w.x - nx) < cfg.snap) {
                    nx = z.selmon.w.x;
                } else if (@abs(z.selmon.w.r() - (nx + c.width())) < cfg.snap) {
                    nx = z.selmon.w.r() - c.width();
                }
                if (@abs(z.selmon.w.y - ny) < cfg.snap) {
                    ny = z.selmon.w.y;
                } else if (@abs(z.selmon.w.b() - (ny + c.height())) < cfg.snap) {
                    ny = z.selmon.w.b() - c.height();
                }
                if (!c.is_floating.now and
                    z.selmon.lt[z.selmon.sellt].arrange != null and
                    (@abs(nx - c.pos.now.x) > cfg.snap or
                        @abs(ny - c.pos.now.y) > cfg.snap))
                {
                    toggleFloating(undefined);
                }
                if (z.selmon.lt[z.selmon.sellt].arrange != null or c.is_floating.now) {
                    var r = c.pos.now;
                    r.x = nx;
                    r.y = ny;
                    c.hintAndResize(r, true);
                }
            },
            X.ButtonRelease => break,
            else => {},
        }
    }
    _ = X.XUngrabPointer(z.dpy, X.CurrentTime);
    const m_opt = c.pos.now.toMonitor(z.mons);
    if (m_opt != z.selmon) {
        if (m_opt) |m| {
            sendMon(global_allocator, c, m);
            z.selmon = m;
            focus(global_allocator, null);
        }
    }
}

/// (dwm) setlayout
pub fn setLayout(arg: *const Arg) void {
    // TODO: check all other instances of tagged access of args. Make sure to
    // use a switch statement before indexing.
    const lt = switch (arg.*) {
        .l => |lt| lt,
        else => return,
    };
    z.selmon.lt[z.selmon.sellt] = lt;
    z.selmon.layout_symbol = lt.symbol;
    if (z.selmon.sel) |_| {
        arrange(global_allocator, z.selmon);
    } else {
        drawbar(global_allocator, z.selmon);
    }
}

/// (dwm) setmfact
pub fn setMFact(arg: *const Arg) void {
    if (z.selmon.lt[z.selmon.sellt].arrange == null) return;
    const f: f32 = switch (arg.*) {
        .f => |v| v,
        else => return,
    };
    if (0.05 <= f and f <= 0.95) {
        z.selmon.mfact = f;
        arrange(global_allocator, z.selmon);
    }
}

/// (dwm) resizemouse
pub fn resizeMouse(_: *const Arg) DwmError!void {
    var c = z.selmon.sel orelse return;
    if (c.isfullscreen) return; // No support moving fullscreen windows by mouse.
    restack(global_allocator, z.selmon);

    // Old client x and y coordinates.
    const ocx = c.pos.now.x;
    const ocy = c.pos.now.y;

    const grab_res = X.XGrabPointer(
        z.dpy,
        z.root,
        X.False,
        MOUSEMASK,
        X.GrabModeAsync,
        X.GrabModeAsync,
        X.None,
        z.cursors.get(.Resize),
        X.CurrentTime,
    );
    if (grab_res != X.GrabSuccess) return;
    if (c.is_floating.now) {
        _ = X.XWarpPointer(z.dpy, X.None, c.win, 0, 0, 0, 0, //
            @intCast(c.pos.now.w + c.bw.now - 1), //
            @intCast(c.pos.now.h + c.bw.now - 1));
    } else {
        _ = X.XWarpPointer(z.dpy, X.None, z.selmon.barwin, 0, 0, 0, 0, //
            @intFromFloat(z.selmon.mfact * @as(f32, @floatFromInt(z.selmon.m.w))), //
            @intCast(@divFloor(z.selmon.m.h, 2)));
    }
    var ev: XEvent = undefined;
    var lasttime: X.Time = 0;
    while (true) {
        _ = X.XMaskEvent(z.dpy, MOUSEMASK | X.ExposureMask | X.SubstructureRedirectMask, &ev);
        switch (ev.type) {
            X.Expose | X.MapRequest | X.ConfigureRequest => try runOne(global_allocator, &ev),
            X.MotionNotify => {
                if (ev.xmotion.time - lasttime <= @divFloor(1000, cfg.refreshrate)) {
                    continue;
                }
                lasttime = ev.xmotion.time;
                const nw: i32 = @max(@as(i32, @intCast(ev.xmotion.x)) - ocx - 2 * @as(i32, @intCast(c.bw.now)) + 1, 1);
                const nh: i32 = @max(@as(i32, @intCast(ev.xmotion.y)) - ocy - 2 * @as(i32, @intCast(c.bw.now)) + 1, 1);
                if (!c.is_floating.now) {
                    const f = @as(f32, @floatFromInt(ev.xmotion.x)) /
                        @as(f32, @floatFromInt(z.selmon.m.w));
                    if (0.05 <= f and f <= 0.95) {
                        z.selmon.mfact = f;
                        arrange(global_allocator, z.selmon);
                    }
                    // toggleFloating(undefined);
                } else if (c.mon.w.x + nw >= z.selmon.w.l() and
                    c.mon.w.x + nw <= z.selmon.w.r() and
                    c.mon.w.y + nh >= z.selmon.w.t() and
                    c.mon.w.y + nh <= z.selmon.w.b())
                {
                    if (!c.is_floating.now and
                        z.selmon.lt[z.selmon.sellt].arrange != null and
                        (@abs(nw - @as(i32, @intCast(c.pos.now.w))) > cfg.snap or
                            @abs(nh - @as(i32, @intCast(c.pos.now.h))) > cfg.snap))
                    {
                        toggleFloating(undefined);
                    }
                }
                if (z.selmon.lt[z.selmon.sellt].arrange == null or c.is_floating.now) {
                    var r = c.pos.now;
                    r.w = @intCast(nw);
                    r.h = @intCast(nh);
                    c.hintAndResize(r, true);
                }
            },
            X.ButtonRelease => break,
            else => {},
        }
    }
    if (c.is_floating.now) {
        _ = X.XWarpPointer(z.dpy, X.None, c.win, 0, 0, 0, 0, //
            @intCast(c.pos.now.w + c.bw.now - 1), //
            @intCast(c.pos.now.h + c.bw.now - 1));
    }
    _ = X.XUngrabPointer(z.dpy, X.CurrentTime);
    while (X.XCheckMaskEvent(z.dpy, X.EnterWindowMask, &ev) != 0) {}
    const m_opt = c.pos.now.toMonitor(z.mons);
    if (m_opt != z.selmon) {
        if (m_opt) |m| {
            sendMon(global_allocator, c, m);
            z.selmon = m;
            focus(global_allocator, null);
        }
    }
}

/// (dwm) sendmon
fn sendMon(allocator: Allocator, c: *Client, m: *Monitor) void {
    if (c.mon == m) return;
    unfocus(c, true);
    c.detach();
    c.detachStack();
    c.mon = m;
    c.tags = m.tagset[m.seltags]; // Assign tags of target monitor.
    c.attach();
    c.attachStack();
    if (c.isfullscreen) {
        c.resize(m.w);
    }
    focus(allocator, null);
    arrange(allocator, null);
}

/// (dwm) togglefloating
pub fn toggleFloating(_: *const Arg) void {
    const sel = z.selmon.sel orelse return;
    if (sel.isfullscreen) return; // No support for making fullscreen windows float.
    sel.is_floating.set(!sel.is_floating.now or sel.is_fixed);
    if (sel.is_floating.now) {
        sel.hintAndResize(sel.pos.now, false);
    }
    arrange(global_allocator, z.selmon);
}

/// (dwm) wintomon
fn wintomon(w: Window) *Monitor {
    var x: c_int = undefined;
    var y: c_int = undefined;
    if (w == z.root and z.getRootPtr(&x, &y)) {
        const r = Rect{ .x = @intCast(x), .y = @intCast(y), .w = 1, .h = 1 };
        // To guarantee a non-null return of `*Monitor`, we deviate a tad from
        // dwm's behaviour and return `selmon` if nothing is found.
        return r.toMonitor(z.mons) orelse (z.mons orelse unreachable);
    }
    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        if (w == m.barwin) return m;
    }
    if (winToClient(w)) |c| return c.mon;
    return z.selmon;
}

/// (dwm) updategeom
fn updategeom(allocator: Allocator, selmon: *?*Monitor) error{OutOfMemory}!bool {
    var dirty = false;
    var mons: *Monitor = undefined;
    {
        // default monitor setup
        mons = z.mons orelse m: {
            z.mons = try Monitor.init(allocator);
            break :m z.mons.?;
        };
        if (mons.w.w != z.s.w or mons.m.h != z.s.h) {
            dirty = true;
            mons.w.w = z.s.w;
            mons.w.h = z.s.h;
            mons.m.w = z.s.w;
            mons.m.h = z.s.h;
            updateBarPosition(mons);
        }
    }
    if (dirty) {
        selmon.* = mons;
        selmon.* = wintomon(z.root);
    }
    return dirty;
}

/// (dwm) setup
fn setup(allocator: Allocator) DwmError!void {
    var utf8string: X.Atom = undefined;
    var sa: C.struct_sigaction = undefined;

    // Do not transform children into zombies when they terminate.
    _ = C.sigemptyset(&sa.sa_mask);
    sa.sa_flags = C.SA_NOCLDSTOP | C.SA_NOCLDWAIT | C.SA_RESTART;
    sa.__sigaction_handler.sa_handler = C.SIG_IGN;
    _ = C.sigaction(C.SIGCHLD, &sa, null);

    // Clean up any zombies (inherited from .xinitrc etc) immediately.
    while (std.c.waitpid(-1, null, std.c.W.NOHANG) > 0) {}

    z.screen = X.DefaultScreen(z.dpy);
    z.s.w = @intCast(X.DisplayWidth(z.dpy, z.screen));
    z.s.h = @intCast(X.DisplayHeight(z.dpy, z.screen));
    log.info("width: {d}, height: {d}", .{ z.s.w, z.s.h });
    z.root = X.RootWindow(z.dpy, z.screen);
    z.drw = try .init(allocator, z.dpy, z.screen, z.root, z.s.w, z.s.h, &cfg.fonts);
    z.lrpad = z.drw.fonts.h;
    z.bar_height = 20;

    var selmon: ?*Monitor = null;
    // Make sure that `selmon` is initialized.
    _ = try updategeom(allocator, &selmon);
    if (selmon) |m| {
        z.selmon = m;
    } else {
        std.debug.print("App could not find the first selected monitor (dwm: selmon)\n", .{});
        return;
    }

    // Initialize atoms.
    utf8string = X.XInternAtom(z.dpy, "UTF8_STRING", X.False);
    z.wmatom.set(.Protocols, X.XInternAtom(z.dpy, "WM_PROTOCOLS", X.False));
    z.wmatom.set(.Delete, X.XInternAtom(z.dpy, "WM_DELETE_WINDOW", X.False));
    z.wmatom.set(.State, X.XInternAtom(z.dpy, "WM_STATE", X.False));
    z.wmatom.set(.TakeFocus, X.XInternAtom(z.dpy, "WM_TAKE_FOCUS", X.False));

    z.netatom.set(.ActiveWindow, X.XInternAtom(z.dpy, "_NET_ACTIVE_WINDOW", X.False));
    z.netatom.set(.Supported, X.XInternAtom(z.dpy, "_NET_SUPPORTED", X.False));
    z.netatom.set(.WMName, X.XInternAtom(z.dpy, "_NET_WM_NAME", X.False));
    z.netatom.set(.WMState, X.XInternAtom(z.dpy, "_NET_WM_STATE", X.False));
    z.netatom.set(.WMCheck, X.XInternAtom(z.dpy, "_NET_SUPPORTING_WM_CHECK", X.False));
    z.netatom.set(.WMFullscreen, X.XInternAtom(z.dpy, "_NET_WM_STATE_FULLSCREEN", X.False));
    z.netatom.set(.WMWindowType, X.XInternAtom(z.dpy, "_NET_WM_WINDOW_TYPE", X.False));
    z.netatom.set(.WMWindowTypeDialog, X.XInternAtom(z.dpy, "_NET_WM_WINDOW_TYPE_DIALOG", X.False));
    z.netatom.set(.ClientList, X.XInternAtom(z.dpy, "_NET_CLIENT_LIST", X.False));

    // Initialize cursors.
    z.cursors.set(.Normal, z.drw.curCreate(X.XC_left_ptr));
    z.cursors.set(.Resize, z.drw.curCreate(X.XC_sizing));
    z.cursors.set(.Move, z.drw.curCreate(X.XC_fleur));

    // Initialize appearance.
    for (std.enums.values(SchemeState)) |ss| {
        const s = z.scheme.getPtr(ss);
        s.* = try z.drw.scmCreate(allocator, cfg.colors.get(ss));
        log.info("fg: {x}, bg: {x}, border: {x}", .{ s.*.fg.pixel, s.*.bg.pixel, s.*.border.pixel });
    }

    // Initialize bars.
    updateBars();
    updateStatus(allocator);

    // Supporting window for NetWMCheck.
    z.wmcheckwin = X.XCreateSimpleWindow(z.dpy, z.root, 0, 0, 1, 1, 0, 0, 0);
    // The @ptrCast is hella sus from dwm. This is supposed to be a const char* in C.
    _ = X.XChangeProperty(z.dpy, z.wmcheckwin, z.netatom.get(.WMCheck), X.XA_WINDOW, 32, X.PropModeReplace, @ptrCast(&z.wmcheckwin), 1);
    _ = X.XChangeProperty(z.dpy, z.wmcheckwin, z.netatom.get(.WMName), utf8string, 8, X.PropModeReplace, "dwm", 3);
    _ = X.XChangeProperty(z.dpy, z.root, z.netatom.get(.WMCheck), X.XA_WINDOW, 32, X.PropModeReplace, @ptrCast(&z.wmcheckwin), 1);

    // EWMH support per view.
    // https://specifications.freedesktop.org/wm/latest/
    _ = X.XChangeProperty(z.dpy, z.root, z.netatom.get(.Supported), X.XA_ATOM, 32, X.PropModeReplace, @ptrCast(&z.netatom.values), @intCast(N(Net)));
    _ = X.XDeleteProperty(z.dpy, z.root, z.netatom.get(.ClientList));

    // Select events.
    {
        var wa: X.XSetWindowAttributes = .{
            .cursor = z.cursors.get(.Normal),
            .event_mask = X.SubstructureRedirectMask | X.SubstructureNotifyMask //
            | X.ButtonPressMask | X.PointerMotionMask | X.EnterWindowMask //
            | X.LeaveWindowMask | X.StructureNotifyMask | X.PropertyChangeMask,
        };
        _ = X.XChangeWindowAttributes(z.dpy, z.root, X.CWEventMask | X.CWCursor, &wa);
        _ = X.XSelectInput(z.dpy, z.root, wa.event_mask);
    }

    grabkeys();
    focus(allocator, null);
}

/// (dwm) unfocus
fn unfocus(client: ?*Client, setfocus: bool) void {
    const c = client orelse return;
    log.info("Unfocusing client at: {*}", .{c});
    grabbuttons(c, false);
    _ = X.XSetWindowBorder(z.dpy, c.win, z.scheme.get(.Normal).border.pixel);
    if (setfocus) {
        _ = X.XSetInputFocus(z.dpy, z.root, X.RevertToPointerRoot, X.CurrentTime);
        _ = X.XDeleteProperty(z.dpy, z.root, z.netatom.get(.ActiveWindow));
    }
}

/// (dwm) focus
fn focus(allocator: Allocator, client: ?*Client) void {
    if (client) |c| {
        log.info("focus({*})", .{c});
    } else log.info("focus(null)", .{});

    var c_opt = client;
    if (if (c_opt) |c| !c.isVisible() else true) {
        // Push the pointer forward until c_opt points to the first visible client.
        c_opt = z.selmon.stack;
        while (c_opt) |c| : (c_opt = c.snext) {
            if (c.isVisible()) {
                break;
            }
        }
    }
    // If the currently selected client in the selected monitor is not `c_opt`,
    // then unfocus it.
    if (z.selmon.sel != c_opt) {
        unfocus(z.selmon.sel, false);
    }
    if (c_opt) |c| {
        z.selmon = c.mon;
        // if the client (that's about to be focused) is urgent, then put it at
        // ease for it is about to be tended to.
        if (c.isurgent) c.setUrgent(z.dpy, false);
        c.detachStack();
        c.attachStack();
        grabbuttons(c, true);
        _ = X.XSetWindowBorder(z.dpy, c.win, z.scheme.get(.Selected).border.pixel);
        c.setFocus();
    } else {
        _ = X.XSetInputFocus(z.dpy, z.root, X.RevertToPointerRoot, X.CurrentTime);
        _ = X.XDeleteProperty(z.dpy, z.root, z.netatom.get(.ActiveWindow));
    }
    z.selmon.sel = c_opt;
    drawbars(allocator);
}

/// (dwm) drawbars
fn drawbars(allocator: Allocator) void {
    var m_opt: ?*Monitor = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        drawbar(allocator, m);
    }
}

/// (dwm) grabbuttons
fn grabbuttons(c: *Client, focused: bool) void {
    updatenumlockmask();
    const modifiers: [4]c_uint = .{ 0, X.LockMask, z.numlockmask, z.numlockmask | X.LockMask };
    _ = X.XUngrabButton(z.dpy, X.AnyButton, X.AnyModifier, c.win);
    if (!focused) {
        _ = X.XGrabButton(
            z.dpy,
            X.AnyButton,
            X.AnyModifier,
            c.win,
            X.False,
            X.ButtonPressMask | X.ButtonReleaseMask,
            X.GrabModeSync,
            X.GrabModeSync,
            X.None,
            X.None,
        );
    }
    for (cfg.buttons) |button| {
        if (button.click == .ClientWin) {
            for (modifiers) |modifier| {
                _ = X.XGrabButton(
                    z.dpy,
                    button.button,
                    button.mask | modifier,
                    c.win,
                    X.False,
                    X.ButtonPressMask | X.ButtonReleaseMask,
                    X.GrabModeAsync,
                    X.GrabModeSync,
                    X.None,
                    X.None,
                );
            }
        }
    }
}

/// (dwm) grabkeys
fn grabkeys() void {
    updatenumlockmask();
    const modifiers: [4]c_uint = .{ 0, X.LockMask, z.numlockmask, z.numlockmask | X.LockMask };

    var start: c_int = undefined;
    var end: c_int = undefined;
    var skip: c_int = undefined;

    _ = X.XUngrabKey(z.dpy, X.AnyKey, X.AnyModifier, z.root);
    _ = X.XDisplayKeycodes(z.dpy, &start, &end);
    const syms: [*]X.KeySym =
        X.XGetKeyboardMapping(z.dpy, @intCast(start), end - start + 1, &skip) orelse
        return;
    defer _ = X.XFree(syms);

    var keycode = start;
    while (keycode < end) : (keycode += 1) {
        for (cfg.keys) |key| {
            // Skip modifier codes, we do that ourselves.
            if (key.sym == syms[@intCast((keycode - start) * skip)]) {
                for (modifiers) |mod| {
                    _ = X.XGrabKey(
                        z.dpy,
                        keycode,
                        key.mod | mod,
                        z.root,
                        X.True,
                        X.GrabModeAsync,
                        X.GrabModeAsync,
                    );
                }
            }
        }
    }
}

/// (dwm) updatenumlockmask
fn updatenumlockmask() void {
    z.numlockmask = 0;
    const modmap = X.XGetModifierMapping(z.dpy);
    if (modmap == null) {
        return;
    }
    defer _ = X.XFreeModifiermap(modmap);
    const mkpm: usize = @intCast(modmap.*.max_keypermod);
    for (0..8) |i| {
        for (0..mkpm) |j| {
            const keycode = modmap.*.modifiermap[i * mkpm + j];
            if (keycode == X.XKeysymToKeycode(z.dpy, X.XK_Num_Lock)) {
                z.numlockmask = @as(u32, 1) << @intCast(i);
            }
        }
    }
}

/// (dwm) cleanup
// Continue to build this up as we go.
fn cleanup(allocator: Allocator) void {
    log.info("Start cleanup()", .{});

    const a: Arg = .{ .ui = ~@as(u32, 0) };
    const foo: Layout = .{ .symbol = "", .arrange = null };

    view(&a);
    z.selmon.lt[z.selmon.sellt] = &foo;

    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        while (m.stack) |c| {
            unmanage(allocator, c, false);
        }
    }
    _ = X.XUngrabKey(z.dpy, X.AnyKey, X.AnyModifier, z.root);
    while (z.mons) |mon| {
        cleanupmon(allocator, mon);
    }
    for (z.cursors.values) |cursor| {
        z.drw.curFree(cursor);
    }
    for (std.enums.values(SchemeState)) |ss| {
        z.drw.scmFree(allocator, z.scheme.get(ss));
    }
    _ = X.XDestroyWindow(z.dpy, z.wmcheckwin);
    z.drw.deinit(allocator);
    _ = X.XSync(z.dpy, X.False);
    _ = X.XSetInputFocus(z.dpy, X.PointerRoot, X.RevertToPointerRoot, X.CurrentTime);
    _ = X.XDeleteProperty(z.dpy, z.root, z.netatom.get(.ActiveWindow));
}

/// (dwm) cleanupmon
fn cleanupmon(allocator: Allocator, mon: *Monitor) void {
    log.info("Start cleanupmon()", .{});
    const mons: *Monitor = z.mons orelse return;
    var m_opt: ?*Monitor = null;

    // First, remove `mon` from the linked list that is `z.mons`.
    if (mon == z.mons) {
        z.mons = mons.next;
    } else {
        m_opt = mons;
        while (m_opt) |m| : (m_opt = m.next) {
            if (m.next == mon) {
                break;
            }
        }
        if (m_opt) |m| {
            m.next = mon.next;
        }
    }
    _ = X.XUnmapWindow(z.dpy, mon.barwin);
    _ = X.XDestroyWindow(z.dpy, mon.barwin);
    allocator.destroy(mon);
}

/// (dwm) updatebars
fn updateBars() void {
    var wa: X.XSetWindowAttributes = .{
        .override_redirect = X.True,
        .background_pixmap = X.ParentRelative,
        .event_mask = X.ButtonPressMask | X.ExposureMask,
    };
    var ch = z.classHint();
    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        if (m.barwin != 0) {
            continue;
        }
        m.barwin = X.XCreateWindow(
            z.dpy,
            z.root,
            m.w.x,
            m.by,
            m.w.w,
            z.bar_height,
            0,
            X.DefaultDepth(z.dpy, z.screen),
            X.CopyFromParent,
            X.DefaultVisual(z.dpy, z.screen),
            X.CWOverrideRedirect | X.CWBackPixmap | X.CWEventMask,
            &wa,
        );
        log.info("Create bar window({d}): (x={d}, y={d}, w={d}, h={d})", .{
            m.barwin,
            m.w.x,
            m.by,
            m.w.w,
            z.bar_height,
        });
        _ = X.XDefineCursor(z.dpy, m.barwin, z.cursors.get(.Normal));
        _ = X.XMapRaised(z.dpy, m.barwin);
        _ = X.XSetClassHint(z.dpy, m.barwin, &ch);
    }
}

/// (dwm) updateStatus
fn updateStatus(allocator: Allocator) void {
    if (z.getTextProp(z.root, X.XA_WM_NAME, &z.stext.buffer)) |len| {
        z.stext.len = len;
    } else {
        z.stext.set(NAME ++ "-" ++ VERSION);
    }
    drawbar(allocator, z.selmon);
}

/// (dwm) spawn
pub fn spawn(arg: *const Arg) void {
    const args = switch (arg.*) {
        .args => |value| value,
        else => return,
    };
    log.info("Called spawn()", .{});
    // TODO: handle the failure case by updating the Key struct.
    const pid = std.posix.fork() catch unreachable;
    if (pid == 0) {
        _ = C.close(X.ConnectionNumber(z.dpy));
        _ = C.setsid();

        var sa: C.struct_sigaction = undefined;
        _ = C.sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;
        sa.__sigaction_handler.sa_handler = C.SIG_DFL;
        _ = C.sigaction(C.SIGCHLD, &sa, null);
        std.posix.execvpeZ(args[0].?, args, std.c.environ) catch {
            @panic("execvp failed.");
        };
    }
}

/// (dwm) tag
pub fn tag(arg: *const Arg) void {
    const mask = switch (arg.*) {
        .ui => |v| if (v & cfg.TAGMASK != 0) v else return,
        else => return,
    };
    if (z.selmon.sel) |c| {
        c.tags = mask & cfg.TAGMASK;
        focus(global_allocator, null);
        arrange(global_allocator, z.selmon);
    }
}

/// (dwm) tagmon
pub fn tagMonitor(arg: *const Arg) void {
    const direction = switch (arg.*) {
        .d => |v| v,
        else => return,
    };

    const sel = z.selmon.sel orelse return;
    const mons = z.mons orelse return;
    if (mons.next == null) return;

    if (directionToMonitor(direction)) |m| {
        sendMon(global_allocator, sel, m);
    }
}

/// (dwm) view
pub fn view(arg: *const Arg) void {
    if (arg.ui & cfg.TAGMASK == z.selmon.tagset[z.selmon.seltags]) {
        return; // nothing to do here.
    }
    z.selmon.seltags ^= 1; // Toggle selected tagset.
    if (arg.ui & cfg.TAGMASK != 0) {
        z.selmon.tagset[z.selmon.seltags] = arg.ui & cfg.TAGMASK;
    }
    focus(global_allocator, null);
    arrange(global_allocator, z.selmon);
}

/// (dwm) tile
pub fn tile(m: *Monitor) void {
    var n: u32 = 0;
    var c_opt = if (m.clients) |c| c.nextTiled() else null;
    while (c_opt) |c| : (c_opt = c.next) n += 1;
    if (n == 0) return;
    const mw: u32 = if (n > m.nmaster)
        (if (m.nmaster != 0) @intFromFloat(@as(f32, @floatFromInt(m.w.w)) * m.mfact) else 0)
    else
        m.w.w;

    var i: u32 = 0;
    var my: i32 = 0; // master's y
    var ty: i32 = 0; // non-master's y
    c_opt = if (m.clients) |c| c.nextTiled() else null;
    while (c_opt) |c| : ({
        c_opt = c.next;
        i += 1;
    }) {
        if (i < m.nmaster) {
            const h = @divFloor(m.w.h - @as(u32, @intCast(my)), @min(n, m.nmaster) - i);
            c.hintAndResize(.{
                .x = m.w.x,
                .y = m.w.y + my,
                .w = @intCast(mw - (2 * c.bw.now)),
                .h = @intCast(h - (2 * c.bw.now)),
            }, false);
            if (my + c.height() < m.w.h) {
                my += c.height();
            }
        } else {
            const h = @divFloor(m.w.h - @as(u32, @intCast(ty)), n - i);
            c.hintAndResize(.{
                .x = m.w.x + @as(i32, @intCast(mw)),
                .y = m.w.y + ty,
                .w = m.w.w - mw - 2 * c.bw.now,
                .h = h - 2 * c.bw.now,
            }, false);
            if (ty + c.height() < m.w.h) {
                ty += c.height();
            }
        }
    }
}

/// (dwm) togglebar
pub fn toggleBar(_: *const Arg) void {
    z.selmon.show_bar = !z.selmon.show_bar;
    updateBarPosition(z.selmon);
    _ = X.XMoveResizeWindow(
        z.dpy,
        z.selmon.barwin,
        z.selmon.w.x,
        z.selmon.by,
        z.selmon.w.w,
        z.bar_height,
    );
    arrange(global_allocator, z.selmon);
}

/// (dwm) toggletag
pub fn toggleTag(arg: *const Arg) void {
    const mask = switch (arg.*) {
        .ui => |v| v,
        else => return,
    };
    const sel = z.selmon.sel orelse return;
    const newtags = sel.tags ^ (mask & cfg.TAGMASK);
    if (newtags != 0) {
        sel.tags = newtags;
        focus(global_allocator, null);
        arrange(global_allocator, z.selmon);
    }
}

/// (dwm) toggleview
pub fn toggleView(arg: *const Arg) void {
    const mask = switch (arg.*) {
        .ui => |v| v,
        else => return,
    };
    const newtagset = z.selmon.tagset[z.selmon.seltags] ^ (mask & cfg.TAGMASK);
    if (newtagset != 0) {
        z.selmon.tagset[z.selmon.seltags] = newtagset;
        focus(global_allocator, null);
        arrange(global_allocator, z.selmon);
    }
}

/// (dwm) pop
pub fn pop(allocator: Allocator, c: *Client) void {
    c.detach();
    c.attach();
    focus(allocator, c);
    arrange(allocator, c.mon);
}

/// (dwm) quit
pub fn quit(_: *const Arg) void {
    log.info("quit() called.", .{});
    z.running = false;
}

/// (dwm) zoom
pub fn zoom(_: *const Arg) void {
    var c: ?*Client = z.selmon.sel orelse return;
    if (c.?.is_floating.now or z.selmon.lt[z.selmon.sellt].arrange == null) return;
    const nextTiled: ?*Client = if (z.selmon.clients) |x| x.nextTiled() else null;
    if (c == nextTiled) {
        c = if (c.?.next) |x| x.nextTiled() else null;
        if (c == null) {
            return;
        }
    }
    pop(global_allocator, c.?);
}

/// (dwm) drawbar
fn drawbar(allocator: Allocator, m: *Monitor) void {
    log.info("drawbar(show={}, height={d}, {*})", .{ m.show_bar, z.bar_height, m });

    if (!m.show_bar) return;

    var tw: u32 = 0;
    const boxs = z.drw.fonts.h / 9;
    const boxw = z.drw.fonts.h / 6 + 2;
    var occ: u32 = 0; // it's a bitmask.
    var urg: u32 = 0; // it's a bitmask.

    // draw status first so it can be overdrawn by tags later
    if (m == z.selmon) { // status is only drawn on selected monitor
        log.debug("drawbar: draw the status because this is the selected monitor.", .{});
        z.drw.setScheme(z.scheme.get(.Normal));
        tw = z.TEXTW(allocator, z.stext.get());
        _ = z.drw.drawText(allocator, .{
            .x = @as(i32, @intCast(m.w.w)) - @as(i32, @intCast(tw)),
            .y = 0,
            .w = tw,
            .h = z.bar_height,
        }, 0, z.stext.get(), 0);
    }
    log.debug("Drawn status text({}). tw={d}", .{ m == z.selmon, tw });

    var c_opt = m.clients;
    while (c_opt) |c| : (c_opt = c.next) {
        occ |= c.tags;
        if (c.isurgent) urg |= c.tags;
    }

    var x: i32 = 0;
    var w: u32 = 0;
    for (0..cfg.tags.len) |i| {
        w = z.TEXTW(allocator, cfg.tags[i].text);
        const tag_mask = @as(u32, 1) << @intCast(i);
        const selected = (m.tagset[m.seltags] & tag_mask) != 0;
        z.drw.setScheme(z.scheme.get(if (selected) .Selected else .Normal));
        _ = z.drw.drawText(
            allocator,
            .{ .x = x, .y = 0, .w = w, .h = z.bar_height },
            z.lrpad / 2,
            cfg.tags[i].text,
            urg & tag_mask,
        );
        if ((occ & tag_mask) != 0) {
            z.drw.drawRect(
                .{ .x = x + boxs, .y = boxs, .w = boxw, .h = boxw },
                filled: {
                    const client = z.selmon.sel orelse break :filled false;
                    break :filled m == z.selmon and (client.tags & tag_mask) != 0;
                },
                (urg & tag_mask) != 0,
            );
        }
        x += @intCast(w);
    }

    w = z.TEXTW(allocator, m.layout_symbol);
    z.drw.setScheme(z.scheme.get(.Normal));
    x = z.drw.drawText(
        allocator,
        .{ .x = x, .y = 0, .w = w, .h = z.bar_height },
        z.lrpad / 2,
        m.layout_symbol,
        0,
    );

    // TODO: what if tw > m.ww?
    w = m.w.w - tw - @as(u32, @intCast(x));
    if (w > z.bar_height) {
        if (m.sel) |c| {
            const name = c.name.get();
            const r = Rect{ .x = x, .y = 0, .w = w, .h = z.bar_height };
            z.drw.setScheme(z.scheme.get(if (m == z.selmon) .Bar else .Normal));
            _ = z.drw.drawText(allocator, r, z.lrpad / 2, name, 0);
        } else {
            z.drw.setScheme(z.scheme.get(.Normal));
            z.drw.drawRect(.{ .x = x, .y = 0, .w = w, .h = z.bar_height }, true, true);
        }
    }
    z.drw.map(m.barwin, .{ .x = 0, .y = 0, .w = m.w.w, .h = z.bar_height });
}

pub fn main() !void {
    if (false) return simplemain();
    log.info("{s}", .{line});
    log.info("Started execution of {s}", .{NAME});
    log.info("{s}", .{line});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
        log.info("Closed the allocator", .{});
    }
    const allocator = gpa.allocator();
    global_allocator = allocator;

    var diebuf: [32]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&diebuf);
    var stdout: QuickWrite = .init(&stdout_writer.interface);
    var stderr_writer = std.fs.File.stderr().writer(&diebuf);
    var stderr: QuickWrite = .init(&stderr_writer.interface);

    { // Parse arguments.
        const argv = std.os.argv;
        if (argv.len == 2 and mem.eql(u8, mem.span(argv[1]), "-v"))
            return try stdout.print("{s}-{s}\n", .{ NAME, VERSION })
        else if (argv.len != 1)
            return try stdout.print("usage: {s} [-v]\n", .{NAME});
    }
    if (C.setlocale(C.LC_CTYPE, "") == null or X.XSupportsLocale() == X.False) {
        try stderr.print("warning: no locale support\n", .{});
    }
    z.dpy = X.XOpenDisplay(null) orelse {
        return try stdout.print(NAME ++ ": cannot open display\n", .{});
    };
    defer _ = X.XCloseDisplay(z.dpy);

    check_other_wm();

    try setup(allocator);
    defer cleanup(allocator);

    log.info("{s}", .{line});
    log.info("Completed setup()", .{});
    log.info("{s}", .{line});

    try scan(allocator);
    log.info("{s}", .{line});
    log.info("Completed scan()", .{});
    log.info("{s}", .{line});

    try run(allocator);
}

var test_window: ?Window = null;

fn testWindow() void {
    const w = 100;
    const h = 100;
    var wa: X.XSetWindowAttributes = .{
        .override_redirect = X.True,
        .background_pixmap = X.ParentRelative,
        .event_mask = X.ButtonPressMask | X.ExposureMask,
    };
    const win = X.XCreateWindow(
        z.dpy,
        z.root,
        0,
        0,
        w,
        h,
        0,
        X.DefaultDepth(z.dpy, z.screen),
        X.CopyFromParent,
        X.DefaultVisual(z.dpy, z.screen),
        X.CWOverrideRedirect | X.CWBackPixmap | X.CWEventMask,
        &wa,
    );
    test_window = win;
    // _ = X.XSelectInput(dpy, rootwin, X.ExposureMask | X.ButtonPressMask);
    _ = X.XMapRaised(z.dpy, win);
}

pub fn simplemain() !void {
    const dpy = X.XOpenDisplay(null) orelse {
        return std.debug.print(NAME ++ ": cannot open display\n", .{});
    };
    defer _ = X.XCloseDisplay(dpy);

    const w = 100;
    const h = 100;

    const scr = X.DefaultScreen(dpy);
    const rootwin = X.RootWindow(dpy, scr);
    const pixmap = X.XCreatePixmap(dpy, rootwin, w, h, @intCast(X.DefaultDepth(dpy, scr)));
    // const cmap = X.DefaultColormap(dpy, scr);

    var wa: X.XSetWindowAttributes = .{
        .override_redirect = X.True,
        .background_pixmap = X.ParentRelative,
        .event_mask = X.ButtonPressMask | X.ExposureMask,
    };
    const win = X.XCreateWindow(
        dpy,
        rootwin,
        0,
        0,
        w,
        h,
        0,
        X.DefaultDepth(dpy, scr),
        X.CopyFromParent,
        X.DefaultVisual(dpy, scr),
        X.CWOverrideRedirect | X.CWBackPixmap | X.CWEventMask,
        &wa,
    );
    const gc = X.XCreateGC(dpy, rootwin, 0, null);
    _ = X.XSetForeground(dpy, gc, X.WhitePixel(dpy, scr));
    _ = X.XSelectInput(dpy, rootwin, X.ExposureMask | X.ButtonPressMask);
    _ = X.XMapRaised(dpy, win);

    var ev: XEvent = undefined;
    while (true) {
        _ = X.XNextEvent(dpy, &ev);
        if (ev.type == X.Expose and ev.xexpose.count < 1) {
            // _ = X.XDrawString(dpy, win, gc, 10, 10, "Hello world", 12);
            _ = X.XDrawString(dpy, pixmap, gc, 10, 10, "Hello world", 12);
            // _ = X.XCopyArea(dpy, pixmap, win, gc, 0, 0, w, h, 0, 0);
            // _ = X.XSync(dpy, X.False);
        } else if (ev.type == X.ButtonPress) {
            break;
        }
    }
}

test {
    _ = @import("small.zig");
}
