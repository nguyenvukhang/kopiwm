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
const Cur = @import("enums.zig").Cur;
const Net = @import("enums.zig").Net;
const Rect = @import("rect.zig").Rect;
const SchemeState = @import("enums.zig").SchemeState;
const ColorScheme = @import("drw.zig").ColorScheme;
const N = @import("enums.zig").N;

// TODO: re-enable this in production.
const SAID_AND_DONE = false;

// X11 stuff.
const X = @import("c_lib.zig").X;
const Window = X.Window;
const Display = X.Display;
const XErrorEvent = X.XErrorEvent;

var z: dwmz.App = .{};

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
    // var wa: X.XSetWindowAttributes = undefined;
    var utf8string: X.Atom = undefined;
    var sa: C.struct_sigaction = undefined;

    // do not transform children into zombies when they terminate
    _ = C.sigemptyset(&sa.sa_mask);
    sa.sa_flags = C.SA_NOCLDSTOP | C.SA_NOCLDWAIT | C.SA_RESTART;
    sa.__sigaction_handler.sa_handler = C.SIG_IGN;
    _ = C.sigaction(C.SIGCHLD, &sa, null);

    // clean up any zombies (inherited from .xinitrc etc) immediately
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

    // init atoms
    utf8string = X.XInternAtom(z.dpy, "UTF8_STRING", False);
    z.wmatom[@intFromEnum(WM.Protocols)] = X.XInternAtom(z.dpy, "WM_PROTOCOLS", False);
    z.wmatom[@intFromEnum(WM.Delete)] = X.XInternAtom(z.dpy, "WM_DELETE_WINDOW", False);
    z.wmatom[@intFromEnum(WM.State)] = X.XInternAtom(z.dpy, "WM_STATE", False);
    z.wmatom[@intFromEnum(WM.TakeFocus)] = X.XInternAtom(z.dpy, "WM_TAKE_FOCUS", False);
    z.netatom[@intFromEnum(Net.ActiveWindow)] = X.XInternAtom(z.dpy, "_NET_ACTIVE_WINDOW", False);
    z.netatom[@intFromEnum(Net.Supported)] = X.XInternAtom(z.dpy, "_NET_SUPPORTED", False);
    z.netatom[@intFromEnum(Net.WMName)] = X.XInternAtom(z.dpy, "_NET_WM_NAME", False);
    z.netatom[@intFromEnum(Net.WMState)] = X.XInternAtom(z.dpy, "_NET_WM_STATE", False);
    z.netatom[@intFromEnum(Net.WMCheck)] = X.XInternAtom(z.dpy, "_NET_SUPPORTING_WM_CHECK", False);
    z.netatom[@intFromEnum(Net.WMFullscreen)] = X.XInternAtom(z.dpy, "_NET_WM_STATE_FULLSCREEN", False);
    z.netatom[@intFromEnum(Net.WMWindowType)] = X.XInternAtom(z.dpy, "_NET_WM_WINDOW_TYPE", False);
    z.netatom[@intFromEnum(Net.WMWindowTypeDialog)] = X.XInternAtom(z.dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False);
    z.netatom[@intFromEnum(Net.ClientList)] = X.XInternAtom(z.dpy, "_NET_CLIENT_LIST", False);

    // init cursors
    z.cursors[@intFromEnum(Cur.Normal)] = z.drw.curCreate(X.XC_left_ptr);
    z.cursors[@intFromEnum(Cur.Resize)] = z.drw.curCreate(X.XC_sizing);
    z.cursors[@intFromEnum(Cur.Move)] = z.drw.curCreate(X.XC_fleur);

    // init appearance
    z.scheme = try allocator.alloc(*ColorScheme, cfg.colors.len);
    for (z.scheme, cfg.colors) |*out, scheme| {
        out.* = try z.drw.scmCreate(allocator, scheme);
    }
    for (z.scheme) |s| {
        log.info("fg: {x}, bg: {x}, border: {x}", .{ s.fg.pixel, s.bg.pixel, s.border.pixel });
    }

    // init bars
    updatebars();
    updatestatus(allocator);

    // TODO: continue from here after drw.zig is complete
    // /* supporting window for NetWMCheck */
    // wmcheckwin = XCreateSimpleWindow(dpy, root, 0, 0, 1, 1, 0, 0, 0);
    // XChangeProperty(dpy, wmcheckwin, netatom[NetWMCheck], XA_WINDOW, 32,
    //     PropModeReplace, (unsigned char *) &wmcheckwin, 1);
    // XChangeProperty(dpy, wmcheckwin, netatom[NetWMName], utf8string, 8,
    //     PropModeReplace, (unsigned char *) "dwm", 3);
    // XChangeProperty(dpy, root, netatom[NetWMCheck], XA_WINDOW, 32,
    //     PropModeReplace, (unsigned char *) &wmcheckwin, 1);
    // /* EWMH support per view */
    // XChangeProperty(dpy, root, netatom[NetSupported], XA_ATOM, 32,
    //     PropModeReplace, (unsigned char *) netatom, NetLast);
    // XDeleteProperty(dpy, root, netatom[NetClientList]);
    // /* select events */
    // wa.cursor = cursor[CurNormal]->cursor;
    // wa.event_mask = SubstructureRedirectMask|SubstructureNotifyMask
    //     |ButtonPressMask|PointerMotionMask|EnterWindowMask
    //     |LeaveWindowMask|StructureNotifyMask|PropertyChangeMask;
    // XChangeWindowAttributes(dpy, root, CWEventMask|CWCursor, &wa);
    // XSelectInput(dpy, root, wa.event_mask);
    // grabkeys();
    // focus(NULL);
}

/// [dwm] cleanup
// Continue to build this up as we go.
fn cleanup(allocator: Allocator) !void {
    log.info("Start cleanup()", .{});
    while (z.mons) |mon| {
        cleanupmon(allocator, mon);
    }
    for (z.cursors) |cursor| {
        z.drw.curFree(cursor);
    }
    for (z.scheme) |scheme| {
        z.drw.scmFree(allocator, scheme);
    }
    allocator.free(z.scheme);
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
    {
        const n = @min(build_opts.name.len, z.updatebars_buffer.len);
        @memcpy(z.updatebars_buffer[0..n], build_opts.name[0..n]);
    }
    var ch: X.XClassHint = .{ .res_class = &z.updatebars_buffer, .res_name = &z.updatebars_buffer };
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
        _ = X.XDefineCursor(z.dpy, m.barwin, z.cursors[@intFromEnum(Cur.Normal)]);
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
    const b = gettextprop(z.root, X.XA_WM_NAME, &z.stext_buf);
    if (b == 0) {
        z.setStatusText(build_opts.name ++ "-" ++ build_opts.version);
    } else {
        z.stext = z.stext_buf[0..b];
    }
    if (z.selmon) |m| drawbar(allocator, m);
}

fn drawbar(allocator: Allocator, m: *Monitor) void {
    if (!m.show_bar) {
        return;
    }

    // var w = 0;
    var tw: u32 = 0;
    // var boxs = z.drw.fonts.?.h / 9;
    // var boxw = z.drw.fonts.?.h / 6 + 2;
    // var i = 0;
    var occ: u32 = 0; // it's a bitmask.
    var urg: u32 = 0; // it's a bitmask.

    // var c: *Client = undefined;

    // draw status first so it can be overdrawn by tags later
    if (m == z.selmon) { // status is only drawn on selected monitor
        z.drw.setScheme(z.scheme[@intFromEnum(SchemeState.Normal)]);
        tw = z.TEXTW(allocator, z.stext);
        _ = z.drw.drawText(allocator, .{
            .x = @as(i32, @intCast(m.ww)) - @as(i32, @intCast(tw)),
            .y = 0,
            .w = tw,
            .h = z.bar_height,
        }, 0, z.stext, 0);
    }

    var c_opt = m.clients;
    while (c_opt) |c| : (c_opt = c.next) {
        occ |= c.tags;
        if (c.isurgent) urg |= c.tags;
    }

    // var x: i32 = 0;
    var w: u32 = 0;
    for (cfg.tags) |tag| {
        w = z.TEXTW(allocator, tag);

        //     drw_setscheme(
        //         drw,
        //         scheme[m->tagset[m->seltags] & 1 << i ? SchemeSel : SchemeNorm]);
    }

    // for (i = 0; i < LENGTH(tags); i++) {
    //     w = TEXTW(tags[i]);
    //     drw_setscheme(
    //         drw,
    //         scheme[m->tagset[m->seltags] & 1 << i ? SchemeSel : SchemeNorm]);
    //     drw_text(drw, x, 0, w, bh, lrpad / 2, tags[i], urg & 1 << i);
    //     if (occ & 1 << i) {
    //         drw_rect(drw, x + boxs, boxs, boxw, boxw,
    //                  m == selmon && selmon->sel && selmon->sel->tags & 1 << i,
    //                  urg & 1 << i);
    //     }
    //     x += w;
    // }
    // w = TEXTW(m->ltsymbol);
    // drw_setscheme(drw, scheme[SchemeNorm]);
    // x = drw_text(drw, x, 0, w, bh, lrpad / 2, m->ltsymbol, 0);
    //
    // if ((w = m->ww - tw - x) > bh) {
    //     if (m->sel) {
    //         drw_setscheme(drw, scheme[m == selmon ? SchemeBar : SchemeNorm]);
    //         drw_text(drw, x, 0, w, bh, lrpad / 2, m->sel->name, 0);
    //         if (m->sel->isfloating) {
    //             drw_rect(drw, x + boxs, boxs, boxw, boxw, m->sel->isfixed, 0);
    //         }
    //     } else {
    //         drw_setscheme(drw, scheme[SchemeNorm]);
    //         drw_rect(drw, x, 0, w, bh, 1, 1);
    //     }
    // }
    // drw_map(drw, m->barwin, 0, 0, m->ww, bh);

}

pub fn main() !void {
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
