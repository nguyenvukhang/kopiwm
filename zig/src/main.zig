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
const Net = @import("enums.zig").Net;
const Rect = @import("rect.zig").Rect;
const SchemeState = @import("enums.zig").SchemeState;
const ColorScheme = @import("drw.zig").ColorScheme;
const N = @import("enums.zig").N;
const NAME = @import("build_opts").name;
const VERSION = @import("build_opts").version;

// TODO: re-enable this in production.
const SAID_AND_DONE = true;

// X11 stuff.
const X = @import("c_lib.zig").X;
const C = @import("c_lib.zig").C;
const Window = X.Window;
const Display = X.Display;
const XErrorEvent = X.XErrorEvent;

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

/// [dwm] xerrorstart
fn xerrorstart(_dpy: ?*Display, _event: [*c]XErrorEvent) callconv(.c) c_int {
    log.info("(xerrorstart)", .{});
    _ = _dpy;
    _ = _event;
    std.debug.print(NAME ++ ": another window manager is already running\n", .{});
    std.process.exit(1);
}

/// [dwm] xerror
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

fn check_other_wm() void {
    xerrorlib = X.XSetErrorHandler(xerrorstart);
    // this causes an error if some other window manager is running
    _ = X.XSelectInput(z.dpy, X.DefaultRootWindow(z.dpy), X.SubstructureRedirectMask);
    _ = X.XSync(z.dpy, X.False);
    _ = X.XSetErrorHandler(xerror);
    _ = X.XSync(z.dpy, X.False);
}

/// [dwm] updatebarpos
fn updatebarpos(m: *Monitor) void {
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

/// [dwm] INTERSECT
fn intersect(x: i32, y: i32, w: i32, h: i32, m: *Monitor) i32 {
    return @max(0, @min(x + w, m.wx + @as(i32, @intCast(m.ww))) - @max(x, m.wx)) *
        @max(0, @min(y + h, m.wy + @as(i32, @intCast(m.wh))) - @max(y, m.wy));
}

/// [dwm] wintoclient
/// Searches all the monitors and all of their clients for one that matches
/// the window search query. Returns the first hit.
fn wintoclient(w: Window) ?*Client {
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

fn getstate(w: Window) i32 {
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

/// [dwm] manage
fn manage(allocator: Allocator, w: Window, wa: *X.XWindowAttributes) error{OutOfMemory}!void {
    const c = try allocator.create(Client);
    c.* = .init(&z, w, wa);
    var trans: Window = X.None;
    var wc: X.XWindowChanges = undefined;
    // var t: *Client = undefined;

    c.updateTitle();
    blk: {
        if (X.XGetTransientForHint(z.dpy, w, &trans) == X.True) {
            // This seems to make very little sense if there is a bijection between
            // clients and windows.
            if (wintoclient(w)) |other_client| {
                c.tags = other_client.tags;
                c.mon = other_client.mon;
                break :blk;
            }
        }
        c.mon = z.selmon orelse {
            @panic("Tried unwrapping an optional `selmon`.");
        };
        c.applyRules();
    }
    if (X.XGetTransientForHint(z.dpy, w, &trans) == X.True) {}
    var r = &c.*.pos.curr;

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

    wc.border_width = c.bw.curr;
    _ = X.XConfigureWindow(z.dpy, w, X.CWBorderWidth, &wc);
    _ = X.XSetWindowBorder(z.dpy, w, z.scheme.get(.Normal).border.pixel);

    c.configure(z.dpy); // propagates border_width, if size doesn't change
    c.updateWindowType();
    c.updateSizeHints();
    c.updateWMHints();

    _ = X.XSelectInput(z.dpy, w, X.EnterWindowMask | X.FocusChangeMask | X.PropertyChangeMask | X.StructureNotifyMask);

    grabbuttons(c, false);

    if (!c.is_floating.curr) {
        c.is_floating = .init(trans != X.None or c.is_fixed);
    }
    if (c.is_floating.curr) {
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
        c.pos.curr.x + 2 * @as(i32, @intCast(z.s.w)),
        c.pos.curr.y,
        c.pos.curr.w,
        c.pos.curr.h,
    ); // dwm: some windows require this.
    // me: I have no idea why. Looks like we're pushing the window off the screen.

    // setclientstate(c, NormalState);
    // if (c.mon == selmon) {
    //     unfocus(selmon->sel, 0);
    // }
    // c.mon->sel = c;
    // arrange(c.mon);
    // XMapWindow(dpy, c.win);
    // focus(NULL);
}

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

    i = 0;
    while (i < num) : (i += 1) {
        const r1 = X.XGetWindowAttributes(z.dpy, wins[i], &wa);
        if (r1 == X.False or wa.override_redirect == X.True) {
            continue;
        }
        if (X.XGetTransientForHint(z.dpy, wins[i], &d1) == X.True) {
            continue;
        }
        // TODO: get back here with getstate and manage.
        // X.Status

        if (wa.map_state == X.IsViewable or getstate(wins[i]) == X.IconicState) {
            try manage(allocator, wins[i], &wa);
        }
    }
    i = 0;
    while (i < num) : (i += 1) {} // now the transients

    // for (i = 0; i < num; i++) {
    //     if (!XGetWindowAttributes(dpy, wins[i], &wa) ||
    //         wa.override_redirect ||
    //         XGetTransientForHint(dpy, wins[i], &d1)) {
    //         continue;
    //     }
    //     if (wa.map_state == IsViewable ||
    //         getstate(wins[i]) == IconicState) {
    //         manage(wins[i], &wa);
    //     }
    // }
    // for (i = 0; i < num; i++) { /* now the transients */
    //     if (!XGetWindowAttributes(dpy, wins[i], &wa)) {
    //         continue;
    //     }
    //     if (XGetTransientForHint(dpy, wins[i], &d1) &&
    //         (wa.map_state == IsViewable ||
    //          getstate(wins[i]) == IconicState)) {
    //         manage(wins[i], &wa);
    //     }
    // }
    // if (wins) {
    //     XFree(wins);
    // }
}

/// [dwm] wintomon
/// TODO: revist this after all is said and done and see if we can guarantee
/// non-null. That all depends on if selmon is always non-null.
fn wintomon(w: Window) ?*Monitor {
    var x: c_int = undefined;
    var y: c_int = undefined;
    if (w == z.root and z.getRootPtr(&x, &y)) {
        const r = Rect{ .x = @intCast(x), .y = @intCast(y), .w = 1, .h = 1 };
        return r.toMonitor(z.selmon, z.mons);
    }
    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        if (w == m.barwin) {
            return m;
        }
    }
    if (wintoclient(w)) |client| {
        return client.mon;
    }
    return z.selmon;
}

/// [dwm] updategeom
fn updategeom(allocator: Allocator) error{OutOfMemory}!bool {
    var dirty = false;
    var mons: *Monitor = undefined;
    log.info("Start updategeom", .{});
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
            updatebarpos(mons);
        }
    }
    log.info("updategeom.dirty? {}", .{dirty});
    if (dirty) {
        z.selmon = mons;
        z.selmon = wintomon(z.root);
    }
    return dirty;
}

/// [dwm] setup
fn setup(allocator: Allocator) !void {
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
    z.drw = .init(z.dpy.?, z.screen, z.root, z.s.w, z.s.h);
    {
        const f = try z.drw.fontsetCreate(allocator, &cfg.fonts);
        if (f == null) {
            // Empty linked list. No fonts loaded.
            std.debug.print("no fonts could be loaded.\n", .{});
            return;
        }
    }
    z.lrpad = z.drw.fonts.h;
    z.bar_height = z.drw.fonts.h + 2;
    _ = try updategeom(allocator);

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
    updatebars();
    updatestatus(allocator);

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

/// [dwm] unfocus
fn unfocus(client: ?*Client, setfocus: bool) void {
    // TODO: translate this.
    _ = client;
    _ = setfocus;
}

/// [dwm] focus
fn focus(allocator: Allocator, client: ?*Client) void {
    var c_opt = client;
    if (if (c_opt) |c| !c.isVisible() else true) {
        c_opt = if (z.selmon) |m| m.stack else null;
        // Push the pointer forward until c_opt points to the first visible client.
        while (c_opt) |c| : (c_opt = c.snext) {
            if (c.isVisible()) {
                break;
            }
        }
    }
    // If the currently selected client in the selected monitor is not `c_opt`,
    // then unfocus it.
    if (z.selmon) |selected_monitor| {
        if (selected_monitor.sel != c_opt) {
            unfocus(selected_monitor.sel, false);
        }
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
    if (z.selmon) |m| m.sel = c_opt;
    drawbars(allocator);
}

/// [dwm] drawbars
fn drawbars(allocator: Allocator) void {
    var m_opt: ?*Monitor = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        drawbar(allocator, m);
    }
}

/// [dwm] grabbuttons
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

/// [dwm] grabkeys
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
    _ = X.XFree(syms);
    log.info("grabkeys() finished!", .{});
}

/// [dwm] updatenumlockmask
fn updatenumlockmask() void {
    log.info("Called updatenumlockmask", .{});
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

/// [dwm] cleanup
// Continue to build this up as we go.
fn cleanup(allocator: Allocator) void {
    log.info("Start cleanup()", .{});
    while (z.mons) |mon| {
        cleanupmon(allocator, mon);
    }
    for (z.cursors.values) |cursor| {
        z.drw.curFree(cursor);
    }
    for (std.enums.values(SchemeState)) |ss| {
        z.drw.scmFree(allocator, z.scheme.get(ss));
    }
    z.drw.deinit(allocator);
}

/// [dwm] cleanupmon
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

/// [dwm] updatebars
fn updatebars() void {
    var wa: X.XSetWindowAttributes = .{
        .override_redirect = X.True,
        .background_pixmap = X.ParentRelative,
        .event_mask = X.ButtonPressMask | X.ExposureMask,
    };
    var ch = z.classHint();
    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        if (m.barwin == 0) {
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
        _ = X.XDefineCursor(z.dpy, m.barwin, z.cursors.get(.Normal));
        _ = X.XMapRaised(z.dpy, m.barwin);
        _ = X.XSetClassHint(z.dpy, m.barwin, &ch);
    }
}

/// [dwm] updatestatus
fn updatestatus(allocator: Allocator) void {
    if (z.getTextProp(z.root, X.XA_WM_NAME, &z.stext.buffer)) |len| {
        z.stext.len = len;
    } else {
        z.stext.set(NAME ++ "-" ++ VERSION);
    }
    if (z.selmon) |m| drawbar(allocator, m);
}

fn drawbar(allocator: Allocator, m: *Monitor) void {
    if (!m.show_bar) {
        return;
    }

    var tw: u32 = 0;
    const boxs = z.drw.fonts.h / 9;
    const boxw = z.drw.fonts.h / 6 + 2;
    var occ: u32 = 0; // it's a bitmask.
    var urg: u32 = 0; // it's a bitmask.

    // draw status first so it can be overdrawn by tags later
    if (m == z.selmon) { // status is only drawn on selected monitor
        z.drw.setScheme(z.scheme.get(.Normal));
        tw = z.TEXTW(allocator, z.stext.get());
        _ = z.drw.drawText(allocator, .{
            .x = @as(i32, @intCast(m.w.w)) - @as(i32, @intCast(tw)),
            .y = 0,
            .w = tw,
            .h = z.bar_height,
        }, 0, z.stext.get(), 0);
    }

    var c_opt = m.clients;
    while (c_opt) |c| : (c_opt = c.next) {
        occ |= c.tags;
        if (c.isurgent) urg |= c.tags;
    }

    var x: i32 = 0;
    var w: u32 = 0;
    for (0..cfg.tags.len) |i| {
        w = z.TEXTW(allocator, cfg.tags[i]);
        const tag_mask = @as(u32, 1) << @intCast(i);
        const selected = (m.tagset[m.seltags] & tag_mask) != 0;
        z.drw.setScheme(z.scheme.get(if (selected) .Selected else .Normal));
        _ = z.drw.drawText(
            allocator,
            .{ .x = x, .y = 0, .w = w, .h = z.bar_height },
            z.lrpad / 2,
            cfg.tags[i],
            urg & tag_mask,
        );
        if ((occ & tag_mask) != 0) {
            z.drw.drawRect(
                .{ .x = x + boxs, .y = boxs, .w = boxw, .h = boxw },
                filled: {
                    const selmon = z.selmon orelse break :filled false;
                    const client = selmon.sel orelse break :filled false;
                    break :filled m == selmon and (client.tags & tag_mask) != 0;
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
    log.info("STARTED EXECUTION OF DWMZ", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const argv = std.os.argv;
    log.info("argc = {d}", .{argv.len});
    for (argv[1..]) |arg| {
        log.info("argv = {s}", .{arg});
    }

    var diebuf: [32]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&diebuf);
    var stdout: QuickWrite = .init(&stdout_writer.interface);
    var stderr_writer = std.fs.File.stderr().writer(&diebuf);
    var stderr: QuickWrite = .init(&stderr_writer.interface);

    if (argv.len == 2 and mem.eql(u8, mem.span(argv[1]), "-v")) {
        return try stdout.print("{s}-{s}\n", .{ NAME, VERSION });
    } else if (argv.len != 1) {
        return try stdout.print("usage: {s} [-v]\n", .{NAME});
    }
    if (C.setlocale(C.LC_CTYPE, "") == null or X.XSupportsLocale() == X.False) {
        try stderr.print("warning: no locale support\n", .{});
    }
    z.dpy = X.XOpenDisplay(null) orelse {
        return try stdout.print(NAME ++ ": cannot open display\n", .{});
    };
    defer _ = X.XCloseDisplay(z.dpy);

    if (SAID_AND_DONE) check_other_wm();

    log.info("Start setup()", .{});
    try setup(allocator);
    defer cleanup(allocator);

    log.info("Completed setup()", .{});

    log.info("Start main loop", .{});
    try scan(allocator);

    log.info("The end! Starting cleanup...", .{});
}

test {
    _ = @import("small.zig");
}
