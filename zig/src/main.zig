const std = @import("std");
const mem = std.mem;
const log = std.log;
const build_opts = @import("build_opts");
const dwmz = @import("app.zig");
const drw = @import("drw.zig").drw;
const cfg = @import("config.zig");
const Allocator = std.mem.Allocator;
const Monitor = @import("monitor.zig").Monitor;
const Client = @import("client.zig").Client;

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

const c = @cImport({
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

fn xerrorstart(_dpy: ?*Display, _event: [*c]XErrorEvent) callconv(.c) c_int {
    log.info("(xerrorstart)", .{});
    _ = _dpy;
    _ = _event;
    std.debug.print("dwm: another window manager is already running\n", .{});
    std.process.exit(1);
}

fn xerror(_dpy: ?*Display, _err: [*c]XErrorEvent) callconv(.c) c_int {
    _ = _dpy;
    _ = _err;
    @panic("TODO");
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
        m.wy = if (m.top_bar) m.wy + z.bar_height else m.wy;
    } else {
        m.by = -z.bar_height;
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
    return @max(0, @min(x + w, m.wx + m.ww) - @max(x, m.wx)) *
        @max(0, @min(y + h, m.wy + m.wh) - @max(y, m.wy));
}

/// [dwm] recttomon
/// Selects the monitor with the greatest area intersection with the bounding
/// rectangle given.
fn recttomon(x: i32, y: i32, w: i32, h: i32) ?*Monitor {
    var r = z.selmon;
    var max_area: i32 = 0;
    var a: i32 = 0;
    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        a = intersect(x, y, w, h, m);
        if (a > max_area) {
            max_area = a;
            r = m;
        }
    }
    return r;
}

fn wintoclient(m: Window) ?*Client {
    var m_opt = z.mons;
    var c_opt: ?*Client = null;
    while (m_opt) |m| : (m_opt = m.next) {
        c_opt = m.clients;
    }
    return null;
}
// Client *wintoclient(Window w) {
//     Client *c;
//     Monitor *m;
//
//     for (m = mons; m; m = m->next) {
//         for (c = m->clients; c; c = c->next) {
//             if (c->win == w) {
//                 return c;
//             }
//         }
//     }
//     return NULL;
// }

/// TODO: get back here after recttomon and wintoclient.
/// [dwm] wintomon
fn wintomon(w: Window) ?*Monitor {
    // TODO: get back here after getrootptr
    var x: c_int = undefined;
    var y: c_int = undefined;
    if (w == z.root and getrootptr(&x, &y) != 0) {
        return recttomon(x, y, 1, 1);
    }
    var m_opt = z.mons;
    while (m_opt) |m| : (m_opt = m.next) {
        if (w == m.barwin) {
            return m;
        }
    }
    //     if ((c = wintoclient(w))) {
    //         return c->mon;
    //     }
    //     return selmon;
    return null;
}

// TODO: return to this after making the monitor struct and porting `createmon`.
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
        // TODO: uncomment this
        // z.selmon = wintomon(z.root)
    }
    return dirty;
}

fn setup(allocator: Allocator) !void {
    // var wa: X.XSetWindowAttributes = undefined;
    // var utf8string: X.Atom = undefined;
    var sa: c.struct_sigaction = undefined;

    // do not transform children into zombies when they terminate
    _ = c.sigemptyset(&sa.sa_mask);
    sa.sa_flags = c.SA_NOCLDSTOP | c.SA_NOCLDWAIT | c.SA_RESTART;
    sa.__sigaction_handler.sa_handler = c.SIG_IGN;
    _ = c.sigaction(c.SIGCHLD, &sa, null);

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
    z.lrpad = z.drw.fonts.?.h;
    z.bar_height = z.drw.fonts.?.h + 2;
    _ = try updategeom(allocator);

    // TODO: continue from here after drw.zig is complete
    // /* init atoms */
    // utf8string = XInternAtom(dpy, "UTF8_STRING", False);
    // wmatom[WMProtocols] = XInternAtom(dpy, "WM_PROTOCOLS", False);
    // wmatom[WMDelete] = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    // wmatom[WMState] = XInternAtom(dpy, "WM_STATE", False);
    // wmatom[WMTakeFocus] = XInternAtom(dpy, "WM_TAKE_FOCUS", False);
    // netatom[NetActiveWindow] = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
    // netatom[NetSupported] = XInternAtom(dpy, "_NET_SUPPORTED", False);
    // netatom[NetWMName] = XInternAtom(dpy, "_NET_WM_NAME", False);
    // netatom[NetWMState] = XInternAtom(dpy, "_NET_WM_STATE", False);
    // netatom[NetWMCheck] = XInternAtom(dpy, "_NET_SUPPORTING_WM_CHECK", False);
    // netatom[NetWMFullscreen] = XInternAtom(dpy, "_NET_WM_STATE_FULLSCREEN", False);
    // netatom[NetWMWindowType] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
    // netatom[NetWMWindowTypeDialog] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False);
    // netatom[NetClientList] = XInternAtom(dpy, "_NET_CLIENT_LIST", False);
    // /* init cursors */
    // cursor[CurNormal] = drw_cur_create(drw, XC_left_ptr);
    // cursor[CurResize] = drw_cur_create(drw, XC_sizing);
    // cursor[CurMove] = drw_cur_create(drw, XC_fleur);
    // /* init appearance */
    // scheme = ecalloc(LENGTH(colors), sizeof(Clr *));
    // for (i = 0; i < LENGTH(colors); i++)
    //     scheme[i] = drw_scm_create(drw, colors[i], 3);
    // /* init bars */
    // updatebars();
    // updatestatus();
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
    z.drw.deinit(allocator);
}

/// [dwm] cleanupmon
fn cleanupmon(allocator: Allocator, mon: *Monitor) void {
    log.info("Start cleanupmon()", .{});
    const mons: *Monitor = z.mons orelse return;
    var m: ?*Monitor = null;

    // First, remove `mon` from the linked list that is `z.mons`.
    if (mon == z.mons) {
        z.mons = mons.next;
    } else {
        // TODO: replace this with the general iterator.
        m = mons;
        while (m) |m2| : (m = m2.next) {
            if (m2.next == mon) {
                break;
            }
        }
        if (m) |m2| {
            m2.next = mon.next;
        }
    }

    // Then, free the memory allocated to it.
    // TODO: (or rather, noTODO) this error of BadWindow will fix itself once
    // updatebars() is written and called.
    _ = X.XUnmapWindow(z.dpy, mon.barwin);
    _ = X.XDestroyWindow(z.dpy, mon.barwin);
    allocator.destroy(mon);
}

/// [dwm] updatebars
fn updatebars() void {
    const wa: X.XSetWindowAttributes = .{
        .override_redirect = true,
        .background_pixmap = X.ParentRelative,
        .event_mask = X.ButtonPressMask | X.ExposureMask,
    };
    const ch: X.XClassHint = .{ .res_class = "dwm", .res_name = "dwm" };
    var m_cursor = z.mons;
    while (m_cursor) |m| : (m_cursor = m.next) {
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
        // TODO: get back to translating this
        // X.XDefineCursor(z.dpy, m.barwin, cursor[CurNormal]->cursor);
        X.XMapRaised(z.dpy, m.barwin);
        X.XSetClassHint(z.dpy, m.barwin, &ch);
    }
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
        if (c.setlocale(c.LC_CTYPE, "") == null or X.XSupportsLocale() == 0) {
            try stderr.print("warning: no locale support\n", .{});
        }
        z.dpy = X.XOpenDisplay(null) orelse {
            return try stdout.print("dwm: cannot open display\n", .{});
        };
    }
    // TODO: reinstate this check in production.
    // check_other_wm();
    log.info("Start setup()", .{});
    try setup(allocator);
    log.info("Completed setup()", .{});
    log.info("Start cleanup()", .{});
    try cleanup(allocator);
    log.info("Completed cleanup()", .{});
    _ = X.XCloseDisplay(z.dpy);
    log.info("The end!", .{});
}

test {
    _ = @import("small.zig");
}
