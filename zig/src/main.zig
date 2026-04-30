const std = @import("std");
const mem = std.mem;
const log = std.log;
const build_opts = @import("build_opts");
const dwmz = @import("app.zig");

// X11 stuff.
const xlib = @import("xlib.zig").xlib;
const Display = xlib.Display;
const XErrorEvent = xlib.XErrorEvent;

var z: dwmz.App = undefined;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = @import("logger.zig").customLog,
};

const c = @cImport({
    @cInclude("locale.h");
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
    xerrorlib = xlib.XSetErrorHandler(xerrorstart);
    // this causes an error if some other window manager is running
    _ = xlib.XSelectInput(z.dpy, xlib.DefaultRootWindow(z.dpy), xlib.SubstructureRedirectMask);
    _ = xlib.XSync(z.dpy, False);
    _ = xlib.XSetErrorHandler(xerror);
    _ = xlib.XSync(z.dpy, False);
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
        if (c.setlocale(c.LC_CTYPE, "") == null or xlib.XSupportsLocale() == 0) {
            try stderr.print("warning: no locale support\n", .{});
        }
        z.dpy = xlib.XOpenDisplay(null) orelse {
            return try stdout.print("dwm: cannot open display\n", .{});
        };
    }
    check_other_wm();
    _ = xlib.XCloseDisplay(z.dpy);
    log.info("The end!", .{});
}

test {
    _ = @import("small.zig");
}
