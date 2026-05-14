const Xt = @import("x_tutorial.zig");
const App = @import("app.zig").App;
const Layout = @import("layout.zig").Layout;
const DwmError = @import("errors.zig").DwmError;
const LazyFn = @import("lazy_fn.zig").LazyFn;
const Allocator = @import("std").mem.Allocator;

/// (dwm) Clk* enums.
pub const Clk = enum {
    /// User clicked on one of the tags in the tags list (traditionally located
    /// at the top-left) in the bar window.
    TagBar,
    /// User clicked the layout symbol (traditionally located to the left of the
    /// tags) in the bar window.
    LtSymbol,
    /// User clicked the status text (traditionally located at top-right) in the
    /// bar window.
    StatusText,
    /// User clicked the window title in the bar window.
    WinTitle,
    /// User clicked on a client window.
    ClientWin,
    /// The base case: User clicked on none of the above.
    RootWin,
};

/// (dwm) Cur* enums.
/// The different possible states of the mouse cursor.
pub const CursorState = enum {
    Normal,
    Resize,
    Move,
};

/// Represents a possible which one might be in that warrants a unique color scheme.
pub const SchemeState = enum {
    Normal,
    Selected,
    Bar,
};

pub const Key = struct {
    /// Modifier keys, in any.
    mod: c_uint,
    /// X keysym.
    sym: Xt.KeySym,
    lf: LazyFn,

    pub fn init(mod: c_uint, sym: Xt.KeySym, lf: LazyFn) @This() {
        return .{ .mod = mod, .sym = sym, .lf = lf };
    }
};

/// A mouse button.
pub const Button = struct {
    click: Clk,
    mask: c_uint,
    /// One of `Button1`...`Button5` enums in "X11/X.h".
    button: c_uint,
    lf: LazyFn,

    pub fn init(click: Clk, mask: c_uint, button: c_uint, lf: LazyFn) @This() {
        return .{ .click = click, .mask = mask, .button = button, .lf = lf };
    }
};

pub const BarPosition = enum { top, bottom };

pub const Rule = struct {
    class: ?[]const u8,
    instance: ?[]const u8 = null,
    title: ?[]const u8 = null,
    /// Active tags bitmask.
    tags: u32,
    is_floating: bool,
};

pub const Size = struct {
    const Self = @This();
    /// Width.
    w: u32,
    /// Height.
    h: u32,
    pub const zero: Self = .{ .w = 0, .h = 0 };
    pub inline fn eq(lhs: *const Self, rhs: *const Self) bool {
        return lhs.w == rhs.w and lhs.h == rhs.h;
    }
};

pub fn Coordinates(comptime T: type) type {
    return struct {
        const Self = @This();
        /// x-coordinate.
        x: T,
        /// y-coordinate.
        y: T,
        pub const zero: Self = .{ .x = 0, .y = 0 };
        pub inline fn eq(lhs: *const Self, rhs: *const Self) bool {
            return lhs.x == rhs.x and lhs.y == rhs.y;
        }
    };
}

pub const HandlerFnTag = enum { NoAllocE, AllocE, NoAlloc, Alloc };
pub const HandlerFn = union(HandlerFnTag) {
    NoAllocE: *const fn (*Xt.XEvent) DwmError!void,
    AllocE: *const fn (Allocator, *Xt.XEvent) DwmError!void,
    NoAlloc: *const fn (*Xt.XEvent) void,
    Alloc: *const fn (Allocator, *Xt.XEvent) void,
};
