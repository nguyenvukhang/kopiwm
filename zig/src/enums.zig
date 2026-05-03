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
pub const Cur = enum {
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
