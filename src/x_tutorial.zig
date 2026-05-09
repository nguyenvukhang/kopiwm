//! X Library functions with extra notes/docs attached.

const X = @import("c_lib.zig").X;

// -----------------------------------------------------------------------------
// Structs
// -----------------------------------------------------------------------------

/// The `Display` structure serves as the connection to the X server and that
/// contains all the information about that X server.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XOpenDisplay.3.xhtml
pub const Display = X.Display;

pub const Visual = X.Visual;
pub const Window = X.Window;
pub const XSetWindowAttributes = X.XSetWindowAttributes;

// -----------------------------------------------------------------------------
// Functions
// -----------------------------------------------------------------------------

/// The XCreateWindow function creates an unmapped subwindow for a specified
/// parent window, returns the window ID of the created window, and causes the
/// X server to generate a CreateNotify event. The created window is placed on
/// top in the stacking order with respect to siblings.
///
/// The coordinate system has the X axis horizontal and the Y axis vertical
/// with the origin [0,0] at the upper-left corner. Coordinates are integral,
/// in terms of pixels, and coincide with pixel centers. Each window and pixmap
/// has its own coordinate system. For a window, the origin is inside the
/// border at the inside, upper-left corner.
///
/// If you specify any invalid window attribute for a window, a BadMatch error
/// results.
///
/// The created window is not yet displayed (mapped) on the user's display. To
/// display the window, call XMapWindow. The new window initially uses the same
/// cursor as its parent. A new cursor can be defined for the new window by
/// calling XDefineCursor. The window will not be visible on the screen unless
/// it and all of its ancestors are mapped and it is not obscured by any of its
/// ancestors.
///
/// XCreateWindow can generate BadAlloc BadColor, BadCursor, BadMatch,
/// BadPixmap, BadValue, and BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XCreateWindow.3.xhtml
pub inline fn XCreateWindow(
    display: ?*Display,
    parent: Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border_width: c_uint,
    depth: c_int,
    /// Specifies the created window's class. You can pass InputOutput,
    /// InputOnly, or CopyFromParent. A class of CopyFromParent means the class
    /// is taken from the parent.
    class: c_uint,
    visual: [*c]Visual,
    valuemask: c_ulong,
    attributes: [*c]XSetWindowAttributes,
) Window {
    return X.XCreateWindow(
        display,
        parent,
        x,
        y,
        width,
        height,
        border_width,
        depth,
        class,
        visual,
        valuemask,
        attributes,
    );
}

/// The XInternAtom function returns the atom identifier associated with the
/// specified atom_name. If the atom name is not in the Host Portable Character
/// Encoding, the result is implementation-dependent. Uppercase and lowercase
/// matter. The atom will remain defined even after the client's connection
/// closes. It will become undefined only when the last connection to the X
/// server closes.
///
/// XInternAtom can generate BadAlloc and BadValue errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XInternAtom.3.xhtml
pub inline fn XInternAtom(
    display: ?*Display,
    atom_name: [*c]const u8,
    // If only_if_exists is False, the atom is created if it does not exist.
    only_if_exists: bool,
) ?Atom {
    const atom = X.XInternAtom(display, atom_name, @intFromBool(only_if_exists));
    // To quote from X11/X.h:
    // ```c
    // #ifndef None
    // #define None 0L /* universal null resource or null atom */
    // #endif
    // ```
    return if (atom == X.None) null else atom;
}

/// The XSupportsLocale function returns True if Xlib functions are capable of
/// operating under the current locale. If it returns False, Xlib
/// locale-dependent functions for which the XLocaleNotSupported return status
/// is defined will return XLocaleNotSupported. Other Xlib locale-dependent
/// routines will operate in the "C" locale.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XSupportsLocale.3.xhtml
pub inline fn XSupportsLocale() bool {
    return X.XSupportsLocale() != 0;
}

/// The XUnmapWindow function unmaps the specified window and causes the X
/// server to generate an UnmapNotify event. If the specified window is already
/// unmapped, XUnmapWindow has no effect. Normal exposure processing on
/// formerly obscured windows is performed. Any child window will no longer be
/// visible until another map call is made on the parent. In other words, the
/// subwindows are still mapped but are not visible until the parent is mapped.
/// Unmapping a window will generate Expose events on windows that were
/// formerly obscured by it.
///
/// XUnmapWindow can generate a BadWindow error.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XUnmapWindow.3.xhtml
pub inline fn XUnmapWindow(display: ?*Display, window: Window) c_int {
    return X.XUnmapWindow(display, window);
}

// -----------------------------------------------------------------------------
// Enums/Others
// -----------------------------------------------------------------------------

/// At the conceptual level, atoms are unique names that clients can use to
/// communicate information to each other. They can be thought of as a bundle
/// of octets, like a string but without an encoding being specified. The
/// elements are not necessarily ASCII characters, and no case folding happens.
///
/// The protocol designers felt that passing these sequences of bytes back and
/// forth across the wire would be too costly. Further, they thought it
/// important that events as they appear on the wire have a fixed size (in
/// fact, 32 bytes) and that because some events contain atoms, a fixed-size
/// representation for them was needed.
///
/// To allow a fixed-size representation, a protocol request (InternAtom) was
/// provided to register a byte sequence with the server, which returns a
/// 32-bit value (with the top three bits zero) that maps to the byte sequence.
/// The inverse operator is also available (GetAtomName).
///
/// source: https://x.org/releases/X11R7.7/doc/xorg-docs/icccm/icccm.html pub
pub const Atom = X.Atom;

pub const False = X.False;
pub const True = X.True;

////////////////////////////////////////////////////////////////////////////////
// Resources
// * https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html
// * https://x.org/releases/X11R7.7/doc/man/man3/
