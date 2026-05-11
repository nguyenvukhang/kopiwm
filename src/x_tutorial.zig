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
pub const XEvent = X.XEvent;
pub const XSetWindowAttributes = X.XSetWindowAttributes;
pub const XWindowAttributes = X.XWindowAttributes;

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

/// The XGetWindowProperty function returns the actual type of the property; the
/// actual format of the property; the number of 8-bit, 16-bit, or 32-bit items
/// transferred; the number of bytes remaining to be read in the property; and a
/// pointer to the data actually returned. XGetWindowProperty sets the return
/// arguments as follows:
///
/// 1) If the specified property does not exist for the specified window,
///    XGetWindowProperty returns None to actual_type_return and the value zero
///    to actual_format_return and bytes_after_return. The nitems_return
///    argument is empty. In this case, the delete argument is ignored.
///
/// 2) If the specified property exists but its type does not match the
///    specified type, XGetWindowProperty returns the actual property type to
///    actual_type_return, the actual property format (never zero) to
///    actual_format_return, and the property length in bytes (even if the
///    actual_format_return is 16 or 32) to bytes_after_return. It also ignores
///    the delete argument. The nitems_return argument is empty.
///
/// 3) If the specified property exists and either you assign AnyPropertyType to
///    the req_type argument or the specified type matches the actual property
///    type, XGetWindowProperty returns the actual property type to
///    actual_type_return and the actual property format (never zero) to
///    actual_format_return. It also returns a value to bytes_after_return and
///    nitems_return, by defining the following values:
///     * N = actual length of the stored property in bytes (even if the format is 16 or 32)
///     * I = 4 * long_offset
///     * T = N - I
///     * L = MINIMUM(T, 4 * long_length)
///     * A = N - (I + L)
///    The returned value starts at byte index I in the property (indexing from
///    zero), and its length in bytes is L. If the value for long_offset causes L
///    to be negative, a BadValue error results. The value of bytes_after_return
///    is A, giving the number of trailing unread bytes in the stored property.
///
/// If the returned format is 8, the returned data is represented as a char
/// array. If the returned format is 16, the returned data is represented as a
/// short array and should be cast to that type to obtain the elements. If the
/// returned format is 32, the returned data is represented as a long array and
/// should be cast to that type to obtain the elements.
///
/// XGetWindowProperty always allocates one extra byte in prop_return (even if
/// the property is zero length) and sets it to zero so that simple properties
/// consisting of characters do not have to be copied into yet another string
/// before use.
///
/// If delete is True and bytes_after_return is zero, XGetWindowProperty deletes
/// the property from the window and generates a PropertyNotify event on the
/// window.
///
/// The function returns true if it executes successfully. To free the resulting
/// data, use XFree.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGetWindowProperty.3.xhtml
pub inline fn XGetWindowProperty(
    display: ?*Display,
    /// The window whose property you want to obtain.
    w: Window,
    property: Atom,
    /// The offset in the specified property (in 32-bit quantities) where the
    /// data is to be retrieved.
    long_offset: c_long,
    /// The length in 32-bit multiples of the data to be retrieved.
    long_length: c_long,
    /// Determines whether the property is deleted.
    delete: bool,
    /// The atom identifier associated with the property type or
    /// AnyPropertyType.
    req_type: Atom,
    /// The atom identifier that defines the actual type of the property.
    actual_type_return: [*c]Atom,
    /// The actual format of the property.
    actual_format_return: [*c]c_int,
    nitems_return: [*c]c_ulong,
    /// The number of bytes remaining to be read in the property if a partial
    /// read was performed.
    bytes_after_return: [*c]c_ulong,
    /// Returns the data in the specified format. If the returned format is 8,
    /// the returned data is represented as a char array. If the returned
    /// format is 16, the returned data is represented as a array of short int
    /// type and should be cast to that type to obtain the elements. If the
    /// returned format is 32, the property data will be stored as an array of
    /// longs (which in a 64-bit application will be 64-bit values that are
    /// padded in the upper 4 bytes).
    prop_return: [*c][*c]u8,
) bool {
    const result = X.XGetWindowProperty(
        display,
        w,
        property,
        long_offset,
        long_length,
        @intFromBool(delete),
        req_type,
        actual_type_return,
        actual_format_return,
        nitems_return,
        bytes_after_return,
        prop_return,
    );
    // From the original docs:
    // "The function returns Success if it executes successfully."
    return result == X.Success;
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

/// The XSync function flushes the output buffer and then waits until all
/// requests have been received and processed by the X server. Any errors
/// generated must be handled by the error handler. For each protocol error
/// received by Xlib, XSync calls the client application's error handling
/// routine. Any events generated by the server are enqueued into the library's
/// event queue.
///
/// Finally, if you passed False, XSync does not discard the events in the
/// queue. If you passed True, XSync discards all events in the queue,
/// including those events that were on the queue before XSync was called.
/// Client applications seldom need to call XSync.
///
/// source: https://www.x.org/releases/X11R7.7/doc/man/man3/XFlush.3.xhtml
pub inline fn XSync(display: ?*Display, discard: bool) void {
    // According to the docs in the source, the c_int output is only important
    // in the other functions documented on that html page, but not XSync. So
    // we discard it.
    _ = X.XSync(display, @intFromBool(discard));
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
/// source: https://x.org/releases/X11R7.7/doc/xorg-docs/icccm/icccm.html
pub const Atom = X.Atom;

pub const CurrentTime = X.CurrentTime;
pub const ClientMessage = X.ClientMessage;
pub const NoEventMask = X.NoEventMask;
pub const ConfigureNotify = X.ConfigureNotify;
pub const XConfigureEvent = X.XConfigureEvent;

pub const None = X.None;

pub const False = X.False;
pub const True = X.True;

////////////////////////////////////////////////////////////////////////////////
// Resources
// * https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html
// * https://x.org/releases/X11R7.7/doc/man/man3/
