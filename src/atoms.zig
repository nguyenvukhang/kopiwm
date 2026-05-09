//! This file contains X Atoms as enums.

// A good place to start reading is
// https://x.org/releases/X11R7.6/doc/xorg-docs/specs/ICCCM/icccm.html

// There it covers "What are Atoms?":
//| At the conceptual level, atoms are unique names that clients can use to
//| communicate information to each other. They can be thought of as a bundle of
//| octets, like a string but without an encoding being specified. The elements
//| are not necessarily ASCII characters, and no case folding happens.
//|
//| The protocol designers felt that passing these sequences of bytes back and
//| forth across the wire would be too costly. Further, they thought it
//| important that events as they appear on the wire have a fixed size (in fact,
//| 32 bytes) and that because some events contain atoms, a fixed-size
//| representation for them was needed.
//|
//| To allow a fixed-size representation, a protocol request (InternAtom) was
//| provided to register a byte sequence with the server, which returns a 32-bit
//| value (with the top three bits zero) that maps to the byte sequence. The
//| inverse operator is also available (GetAtomName).

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
        array.set(key, X.XInternAtom(dpy, key.asStr(), X.False));
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
