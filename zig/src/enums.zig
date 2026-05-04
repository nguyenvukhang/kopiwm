const X = @import("c_lib.zig").X;
const App = @import("app.zig").App;

/// Count the number of enum variants that exist.
pub fn N(comptime T: type) usize {
    return @import("std").meta.fields(T).len;
}

/// [dwm] WM* atoms.
pub const WM = enum(u8) {
    Protocols,
    Delete,
    State,
    TakeFocus,
};

/// [dwm] Net* atoms.
pub const Net = enum(u8) {
    Supported,
    WMName,
    WMState,
    WMCheck,
    WMFullscreen,
    ActiveWindow,
    WMWindowType,
    WMWindowTypeDialog,
    ClientList,
};

/// [dwm] Clk* enums.
pub const Clk = enum {
    TagBar,
    LtSymbol,
    StatusText,
    WinTitle,
    ClientWin,
    RootWin,
};

/// [dwm] Cur* enums.
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

pub const ArgTag = enum {
    /// Integer.
    i,
    /// Unsigned integer.
    ui,
    /// Float.
    f,
    /// Strings. (used for cli args.)
    s,
};

pub const Arg = union(ArgTag) {
    i: i32,
    ui: u32,
    f: f32,
    s: []const u8,
};

pub const Key = struct {
    /// Modifier keys, in any.
    mod: c_uint,
    /// X keysym.
    sym: X.KeySym,
    /// The callback function.
    func: *const fn (*App, *Arg) void,
    arg: Arg,
};

/// A mouse button.
pub const Button = struct {
    click: Clk,
    mask: c_uint,
    /// See the `Button1`...`Button5` enums in "X11/X.h".
    button: c_uint,
    func: *const fn (*App, *Arg) void,
    arg: Arg,
};

pub const BarPosition = enum { top, bottom };

pub const Rule = struct {
    class: []const u8,
    instance: ?[]const u8,
    title: ?[]const u8,
    /// Active tags bitmask.
    tags: u32,
    is_floating: bool,
    /// TODO: see if this is really needed.
    monitor: usize,
};
