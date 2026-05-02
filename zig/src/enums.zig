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
