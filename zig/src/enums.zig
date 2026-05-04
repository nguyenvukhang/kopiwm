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

/// [dwm] Cur* enums.
/// The different possible states of the mouse cursor.
pub const CursorState = enum {
    Normal,
    Resize,
    Move,
};

/// Represents a possible which one might be in that warrants a unique color scheme.
pub const SchemeState = enum {
    const Self = @This();

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
    key: X.KeySym,
    /// The callback function.
    func: *const fn (*App, *Arg) void,
    arg: Arg,
};
