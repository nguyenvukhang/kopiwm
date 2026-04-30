const std = @import("std");
const mem = std.mem;
const log = std.log;
const build_opts = @import("build_opts");
const dwmz = @import("app.zig");
const drw = @import("drw.zig").drw;

// X11 stuff.
const x = @import("c_lib.zig").x;
const Display = x.Display;
const XErrorEvent = x.XErrorEvent;

var z: dwmz.App = undefined;

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
    return -1;
}

fn xerror(_dpy: ?*Display, _err: [*c]XErrorEvent) callconv(.c) c_int {
    _ = _dpy;
    _ = _err;
    @panic("TODO");
}

var xerrorlib: ?*const fn (?*Display, [*c]XErrorEvent) callconv(.c) c_int = null;

fn check_other_wm() void {
    xerrorlib = x.XSetErrorHandler(xerrorstart);
    // this causes an error if some other window manager is running
    _ = x.XSelectInput(z.dpy, x.DefaultRootWindow(z.dpy), x.SubstructureRedirectMask);
    _ = x.XSync(z.dpy, False);
    _ = x.XSetErrorHandler(xerror);
    _ = x.XSync(z.dpy, False);
}

fn setup() void {
    // var wa: x.XSetWindowAttributes = undefined;
    // var utf8string: x.Atom = undefined;
    var sa: c.struct_sigaction = undefined;

    // do not transform children into zombies when they terminate
    _ = c.sigemptyset(&sa.sa_mask);
    sa.sa_flags = c.SA_NOCLDSTOP | c.SA_NOCLDWAIT | c.SA_RESTART;
    sa.__sigaction_handler.sa_handler = c.SIG_IGN;
    _ = c.sigaction(c.SIGCHLD, &sa, null);

    // clean up any zombies (inherited from .xinitrc etc) immediately
    while (std.c.waitpid(-1, null, std.c.W.NOHANG) > 0) {}

    z.screen = x.DefaultScreen(z.dpy);
    z.sw = x.DisplayWidth(z.dpy, z.screen);
    z.sh = x.DisplayHeight(z.dpy, z.screen);
    log.info("width: {d}, height: {d}", .{ z.sw, z.sh });
    z.root = x.RootWindow(z.dpy, z.screen);
    // TODO: continue from here after drw.zig is complete
    // z.drw = drw.drw_create(z.dpy, z.screen, z.root, z.sw, z.sh);

    // drw = drw_create(dpy, screen, root, sw, sh);
    // if (!drw_fontset_create(drw, fonts, LENGTH(fonts)))
    //     die("no fonts could be loaded.");
    // lrpad = drw->fonts->h;
    // bh = drw->fonts->h + 2;
    // updategeom();
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

pub fn main() !void {
    const argv = std.os.argv;
    std.log.info("argc = {d}", .{argv.len});
    for (argv[1..]) |arg| {
        std.log.info("argv = {s}", .{arg});
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
        if (c.setlocale(c.LC_CTYPE, "") == null or x.XSupportsLocale() == 0) {
            try stderr.print("warning: no locale support\n", .{});
        }
        z.dpy = x.XOpenDisplay(null) orelse {
            return try stdout.print("dwm: cannot open display\n", .{});
        };
    }
    setup();
    check_other_wm();
    _ = x.XCloseDisplay(z.dpy);
    log.info("The end!", .{});
}

test {
    _ = @import("small.zig");
}
