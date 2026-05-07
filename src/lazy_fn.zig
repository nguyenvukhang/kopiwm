const DwmError = @import("errors.zig").DwmError;
const Layout = @import("layout.zig").Layout;

/// Symbolizes a movement, used for navigating to the next/previous entity
/// (Monitor/Client/Window).
pub const Direction = enum {
    Next,
    Prev,
};

pub const ArgTag = enum {
    /// Integer.
    i,
    /// Unsigned integer.
    ui,
    /// Float.
    f,
    /// Direction. (used for relative navigation.)
    d,
    /// Layout.
    l,
    /// String.
    s,
    /// List of strings. (used for cli args.)
    args,
};

pub const Arg = union(ArgTag) {
    i: i32,
    ui: u32,
    f: f32,
    d: Direction,
    l: *const Layout,
    s: []const u8,
    // TODO: figure out if we can get away with setting this as []const []const u8.
    args: [*:null]const ?[*:0]const u8,
};

const FnType = enum {
    MightError,
    NoError,
};

const Fn = union(FnType) {
    MightError: *const fn (*const Arg) DwmError!void,
    NoError: *const fn (*const Arg) void,
};

/// The general lazy function.
pub const LazyFn = struct {
    const Self = @This();

    func: Fn,
    arg: Arg,

    pub fn f(func: *const fn (*const Arg) void, arg: Arg) Self {
        return .{ .func = .{ .NoError = func }, .arg = arg };
    }

    pub fn F(func: *const fn (*const Arg) DwmError!void, arg: Arg) Self {
        return .{ .func = .{ .MightError = func }, .arg = arg };
    }
};
