//! This file contains X Atoms as enums.

// A good place to start reading is
// https://x.org/releases/X11R7.6/doc/xorg-docs/specs/ICCCM/icccm.html

const X = @import("x_tutorial.zig");
const EnumArray = @import("enum_array.zig").EnumArray;
const std = @import("std");

pub fn initializeAtomsForEnum(
    comptime Key: type,
    comptime Value: type,
    array: *EnumArray(Key, Value),
    dpy: *X.Display,
) void {
    for (std.enums.values(Key)) |key| {
        array.set(key, X.XInternAtom(dpy, key.asStr(), false).?);
    }
}

/// (dwm) WM* atoms.
pub const WM = enum {
    const Self = @This();

    Delete,
    Protocols,
    State,
    TakeFocus,

    pub fn asStr(self: *const Self) [*c]const u8 {
        return switch (self.*) {
            .Delete => "WM_DELETE_WINDOW",
            .Protocols => "WM_PROTOCOLS",
            .State => "WM_STATE",
            .TakeFocus => "WM_TAKE_FOCUS",
        };
    }
};

/// (dwm) Net* atoms.
pub const Net = enum {
    const Self = @This();

    ActiveWindow,
    ClientList,
    Supported,
    WMCheck,
    WMFullscreen,
    WMName,
    WMState,
    WMWindowType,
    WMWindowTypeDialog,

    pub fn asStr(self: *const Self) [*c]const u8 {
        return switch (self.*) {
            .ActiveWindow => "_NET_ACTIVE_WINDOW",
            .ClientList => "_NET_CLIENT_LIST",
            .Supported => "_NET_SUPPORTED",
            .WMCheck => "_NET_SUPPORTING_WM_CHECK",
            .WMFullscreen => "_NET_WM_STATE_FULLSCREEN",
            .WMName => "_NET_WM_NAME",
            .WMState => "_NET_WM_STATE",
            .WMWindowType => "_NET_WM_WINDOW_TYPE",
            .WMWindowTypeDialog => "_NET_WM_WINDOW_TYPE_DIALOG",
        };
    }
};
