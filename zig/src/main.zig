const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const log = std.log;
const build_opts = @import("build_opts");
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

// TODO: re-enable this in production.
const SAID_AND_DONE = true;

// X11 stuff.
const X = @import("c_lib.zig").X;
const Window = X.Window;
const Display = X.Display;
const XErrorEvent = X.XErrorEvent;

var z: dwmz.App = .init();

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = @import("logger.zig").customLog,
};

const C = @cImport({
    @cInclude("locale.h");
    @cInclude("signal.h");
});

const True: c_int = 1;
const False: c_int = 0;

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
    std.debug.print(build_opts.name ++ ": another window manager is already running\n", .{});
    std.process.exit(1);
}

/// [dwm] xerror
fn xerror(_dpy: ?*Display, err_event: [*c]XErrorEvent) callconv(.c) c_int {
    _ = _dpy;
    if (err_event == null) {
        std.debug.print(build_opts.name ++ ": called xerror with null XErrorEvent value\n", .{});
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
    std.debug.print(build_opts.name ++ ": fatal error: request code={d}, error code={d}\n", .{ rc, ec });
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
    _ = X.XSync(z.dpy, False);
    _ = X.XSetErrorHandler(xerror);
    _ = X.XSync(z.dpy, False);
}

/// [dwm] updatebarpos
fn updatebarpos(m: *Monitor) void {
    m.wy = m.my;
    m.wh = m.mh;
    if (m.show_bar) {
        m.wh -= @intCast(z.bar_height);
        m.by = if (m.top_bar) m.wy else m.wy + @as(i32, @intCast(m.wh));
        m.wy = if (m.top_bar) m.wy + @as(i32, @intCast(z.bar_height)) else m.wy;
    } else {
        m.by = -@as(i32, @intCast(z.bar_height));
    }
}

/// [dwm] getrootptr
fn getrootptr(x: *c_int, y: *c_int) c_int {
    // dummy variables.
    var d: Window = undefined;
    var d_int: c_int = undefined;
    var d_uint: c_uint = undefined;
    return X.XQueryPointer(z.dpy, z.root, &d, &d, x, y, &d_int, &d_int, &d_uint);
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
            if (c.win == w) {
                return c;
            }
        }
    }
    return null;
}

/// [dwm] wintomon
/// TODO: revist this after all is said and done and see if we can guarantee
/// non-null. That all depends on if selmon is always non-null.
fn wintomon(w: Window) ?*Monitor {
    var x: c_int = undefined;
    var y: c_int = undefined;
    if (w == z.root and getrootptr(&x, &y) != 0) {
        return (Rect{ .x = x, .y = y, .w = 1, .h = 1 }).toMonitor(z.selmon, z.mons);
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
        if (mons.ww != z.sw or mons.mh != z.sh) {
            dirty = true;
            mons.ww = z.sw;
            mons.mw = z.sw;
            mons.wh = z.sh;
            mons.mh = z.sh;
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
    z.sw = @intCast(X.DisplayWidth(z.dpy, z.screen));
    z.sh = @intCast(X.DisplayHeight(z.dpy, z.screen));
    log.info("width: {d}, height: {d}", .{ z.sw, z.sh });
    z.root = X.RootWindow(z.dpy, z.screen);
    z.drw = .init(z.dpy.?, z.screen, z.root, z.sw, z.sh);
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
    utf8string = X.XInternAtom(z.dpy, "UTF8_STRING", False);
    z.wmatom.set(.Protocols, X.XInternAtom(z.dpy, "WM_PROTOCOLS", False));
    z.wmatom.set(.Delete, X.XInternAtom(z.dpy, "WM_DELETE_WINDOW", False));
    z.wmatom.set(.State, X.XInternAtom(z.dpy, "WM_STATE", False));
    z.wmatom.set(.TakeFocus, X.XInternAtom(z.dpy, "WM_TAKE_FOCUS", False));

    z.netatom.set(.ActiveWindow, X.XInternAtom(z.dpy, "_NET_ACTIVE_WINDOW", False));
    z.netatom.set(.Supported, X.XInternAtom(z.dpy, "_NET_SUPPORTED", False));
    z.netatom.set(.WMName, X.XInternAtom(z.dpy, "_NET_WM_NAME", False));
    z.netatom.set(.WMState, X.XInternAtom(z.dpy, "_NET_WM_STATE", False));
    z.netatom.set(.WMCheck, X.XInternAtom(z.dpy, "_NET_SUPPORTING_WM_CHECK", False));
    z.netatom.set(.WMFullscreen, X.XInternAtom(z.dpy, "_NET_WM_STATE_FULLSCREEN", False));
    z.netatom.set(.WMWindowType, X.XInternAtom(z.dpy, "_NET_WM_WINDOW_TYPE", False));
    z.netatom.set(.WMWindowTypeDialog, X.XInternAtom(z.dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False));
    z.netatom.set(.ClientList, X.XInternAtom(z.dpy, "_NET_CLIENT_LIST", False));

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

    // TODO: continue from here after drw.zig is complete
    // focus(NULL);
}

fn grabkeys() void {
    updatenumlockmask();
    // unsigned int i, j, k;
    // unsigned int modifiers[] = {0, LockMask, numlockmask,
    //                             numlockmask | LockMask};
    // int start, end, skip;
    // KeySym *syms;

    var start: c_int = undefined;
    var end: c_int = undefined;
    var skip: c_int = undefined;

    _ = X.XUngrabKey(z.dpy, X.AnyKey, X.AnyModifier, z.root);
    _ = X.XDisplayKeycodes(z.dpy, &start, &end);
    const syms: *X.KeySym = X.XGetKeyboardMapping(z.dpy, @intCast(start), end - start + 1, &skip) orelse return;
    for (@intCast(start)..@intCast(end)) |_| {
        // for (i = 0; i < LENGTH(keys); i++) {
        //     /* skip modifier codes, we do that ourselves */
        //     if (keys[i].keysym == syms[(k - start) * skip]) {
        //         for (j = 0; j < LENGTH(modifiers); j++) {
        //             XGrabKey(dpy, k, keys[i].mod | modifiers[j], root, True,
        //                      GrabModeAsync, GrabModeAsync);
        //         }
        //     }
        // }
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
fn cleanup(allocator: Allocator) !void {
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
        .override_redirect = True,
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
            m.wx,
            m.by,
            m.ww,
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

/// Gets the property of a window in text form, and writes it to `buffer`.
/// Returns the number of valid bytes written to the buffer.
/// [dwm] gettextprop
fn gettextprop(w: Window, atom: X.Atom, buffer: []u8) usize {
    if (buffer.len == 0) {
        return 0;
    }
    var tp: X.XTextProperty = undefined;
    if (X.XGetTextProperty(z.dpy, w, &tp, atom) == 0 or tp.nitems == 0) {
        return 0;
    }
    var l: ?usize = null;
    if (tp.encoding == X.XA_STRING) {
        const value: []const u8 = mem.span(tp.value);
        l = @min(value.len, buffer.len);
        @memcpy(buffer[0..l.?], value[0..l.?]);
    } else {
        var list: [*c][*c]u8 = undefined;
        var n: c_int = undefined;
        const res = X.XmbTextPropertyToTextList(z.dpy, &tp, &list, &n);
        if (res >= X.Success and n > 0 and list != null) {
            const value: []const u8 = mem.span(list[0]);
            l = @min(value.len, buffer.len);
            @memcpy(buffer[0..l.?], value[0..l.?]);
        }
        X.XFreeStringList(list);
    }
    _ = X.XFree(tp.value);
    return l orelse 0;
}

/// [dwm] updatestatus
fn updatestatus(allocator: Allocator) void {
    const b = gettextprop(z.root, X.XA_WM_NAME, &z.stext.buffer);
    if (b == 0) {
        z.stext.set(build_opts.name ++ "-" ++ build_opts.version);
    } else {
        z.stext.len = b;
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
            .x = @as(i32, @intCast(m.ww)) - @as(i32, @intCast(tw)),
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
    w = m.ww - tw - @as(u32, @intCast(x));
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
    z.drw.map(m.barwin, .{ .x = 0, .y = 0, .w = m.ww, .h = z.bar_height });
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

    {
        var buffer: [32]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&buffer);
        var stdout: QuickWrite = .init(&stdout_writer.interface);
        var stderr_writer = std.fs.File.stderr().writer(&buffer);
        var stderr: QuickWrite = .init(&stderr_writer.interface);

        if (argv.len == 2 and mem.eql(u8, mem.span(argv[1]), "-v")) {
            return try stdout.print("{s}-{s}\n", .{ build_opts.name, build_opts.version });
        } else if (argv.len != 1) {
            return try stdout.print("usage: {s} [-v]\n", .{build_opts.name});
        }
        if (C.setlocale(C.LC_CTYPE, "") == null or X.XSupportsLocale() == 0) {
            try stderr.print("warning: no locale support\n", .{});
        }
        z.dpy = X.XOpenDisplay(null) orelse {
            return try stdout.print(build_opts.name ++ ": cannot open display\n", .{});
        };
    }
    if (SAID_AND_DONE) check_other_wm();
    log.info("Start setup()", .{});
    try setup(allocator);
    log.info("Completed setup()", .{});
    log.info("Start cleanup()", .{});
    try cleanup(allocator);
    log.info("Completed cleanup()", .{});
    if (SAID_AND_DONE) _ = X.XCloseDisplay(z.dpy);
    log.info("The end!", .{});
}

test {
    _ = @import("small.zig");
}
