//! X Library functions with extra notes/docs attached.

const X = @import("c_lib.zig").X;

// -----------------------------------------------------------------------------
// XID aliases
// -----------------------------------------------------------------------------

pub const Cursor = X.Cursor;
pub const Drawable = X.Drawable;
pub const KeySym = X.KeySym;
pub const Window = X.Window;

// -----------------------------------------------------------------------------
// Structs
// -----------------------------------------------------------------------------

/// The `Display` structure serves as the connection to the X server and that
/// contains all the information about that X server.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XOpenDisplay.3.xhtml
pub const Display = X.Display;

pub const FcPattern = X.FcPattern;
pub const Visual = X.Visual;
pub const XErrorEvent = X.XErrorEvent;
pub const XEvent = X.XEvent;
pub const XSetWindowAttributes = X.XSetWindowAttributes;
pub const XWindowAttributes = X.XWindowAttributes;
pub const XftColor = X.XftColor;
pub const XftFont = X.XftFont;

// -----------------------------------------------------------------------------
// Functions
// -----------------------------------------------------------------------------

/// The XCloseDisplay function closes the connection to the X server for the
/// display specified in the Display structure and destroys all windows,
/// resource IDs (Window, Font, Pixmap, Colormap, Cursor, and GContext), or
/// other resources that the client has created on this display, unless the
/// close-down mode of the resource has been changed (see XSetCloseDownMode).
/// Therefore, these windows, resource IDs, and other resources should never be
/// referenced again or an error will be generated. Before exiting, you should
/// call XCloseDisplay explicitly so that any pending errors are reported as
/// XCloseDisplay performs a final XSync operation.
///
/// XCloseDisplay can generate a BadGC error.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XOpenDisplay.3.xhtml
pub inline fn XCloseDisplay(display: *Display) void {
    // There is no mention in the docs on that the return value of XCloseDisplay
    // signifies, hence we discard it.
    _ = X.XCloseDisplay(display);
}

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

/// The XOpenDisplay function returns a Display structure that serves as the
/// connection to the X server and that contains all the information about that
/// X server. XOpenDisplay connects your application to the X server through
/// TCP or DECnet communications protocols, or through some local inter-process
/// communication protocol. If the hostname is a host machine name and a single
/// colon (:) separates the hostname and display number, XOpenDisplay connects
/// using TCP streams. If the hostname is not specified, Xlib uses whatever it
/// believes is the fastest transport. If the hostname is a host machine name
/// and a double colon (::) separates the hostname and display number,
/// XOpenDisplay connects using DECnet. A single X server can support any or
/// all of these transport mechanisms simultaneously. A particular Xlib
/// implementation can support many more of these transport mechanisms.
///
/// If successful, XOpenDisplay returns a pointer to a Display structure, which
/// is defined in <X11/Xlib.h>. If XOpenDisplay does not succeed, it returns
/// NULL. After a successful call to XOpenDisplay, all of the screens in the
/// display can be used by the client. The screen number specified in the
/// display_name argument is returned by the DefaultScreen macro (or the
/// XDefaultScreen function). You can access elements of the Display and Screen
/// structures only by using the information macros or functions. For
/// information about using macros and functions to obtain information from the
/// Display structure, see section 2.2.1.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XOpenDisplay.3.xhtml
pub inline fn XOpenDisplay(display_name: [*c]const u8) ?*Display {
    return X.XOpenDisplay(display_name);
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
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XFlush.3.xhtml
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
// Enums
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

// -----------------------------------------------------------------------------
// Bitmasks
// -----------------------------------------------------------------------------

pub const masks = struct {
    pub const ShiftMask = X.ShiftMask;
    pub const ControlMask = X.ControlMask;
    pub const ButtonPressMask = X.ButtonPressMask;
    pub const ButtonReleaseMask = X.ButtonReleaseMask;
    pub const PointerMotionMask = X.PointerMotionMask;

    pub const Mod1Mask = X.Mod1Mask;
    pub const Mod2Mask = X.Mod2Mask;
    pub const Mod3Mask = X.Mod3Mask;
    pub const Mod4Mask = X.Mod4Mask;
    pub const Mod5Mask = X.Mod5Mask;
};

// -----------------------------------------------------------------------------
// Keys and buttons
// -----------------------------------------------------------------------------

pub const keys = struct {
    // zig fmt: off
    pub const XK_a = X.XK_a; pub const XK_b = X.XK_b; pub const XK_c = X.XK_c; pub const XK_d = X.XK_d;
    pub const XK_e = X.XK_e; pub const XK_f = X.XK_f; pub const XK_g = X.XK_g; pub const XK_h = X.XK_h;
    pub const XK_i = X.XK_i; pub const XK_j = X.XK_j; pub const XK_k = X.XK_k; pub const XK_l = X.XK_l;
    pub const XK_m = X.XK_m; pub const XK_n = X.XK_n; pub const XK_o = X.XK_o; pub const XK_p = X.XK_p;
    pub const XK_q = X.XK_q; pub const XK_r = X.XK_r; pub const XK_s = X.XK_s; pub const XK_t = X.XK_t;
    pub const XK_u = X.XK_u; pub const XK_v = X.XK_v; pub const XK_w = X.XK_w; pub const XK_x = X.XK_x;
    pub const XK_y = X.XK_y; pub const XK_z = X.XK_z; // lower caae
    pub const XK_A = X.XK_A; pub const XK_B = X.XK_B; pub const XK_C = X.XK_C; pub const XK_D = X.XK_D;
    pub const XK_E = X.XK_E; pub const XK_F = X.XK_F; pub const XK_G = X.XK_G; pub const XK_H = X.XK_H;
    pub const XK_I = X.XK_I; pub const XK_J = X.XK_J; pub const XK_K = X.XK_K; pub const XK_L = X.XK_L;
    pub const XK_M = X.XK_M; pub const XK_N = X.XK_N; pub const XK_O = X.XK_O; pub const XK_P = X.XK_P;
    pub const XK_Q = X.XK_Q; pub const XK_R = X.XK_R; pub const XK_S = X.XK_S; pub const XK_T = X.XK_T;
    pub const XK_U = X.XK_U; pub const XK_V = X.XK_V; pub const XK_W = X.XK_W; pub const XK_X = X.XK_X;
    pub const XK_Y = X.XK_Y; pub const XK_Z = X.XK_Z; // upper case
    pub const XK_0 = X.XK_0; pub const XK_1 = X.XK_1; pub const XK_2 = X.XK_2; pub const XK_3 = X.XK_3;
    pub const XK_4 = X.XK_4; pub const XK_5 = X.XK_5; pub const XK_6 = X.XK_6; pub const XK_7 = X.XK_7;
    pub const XK_8 = X.XK_8; pub const XK_9 = X.XK_9; // numbers
    // zig fmt: on
    pub const XK_Return = X.XK_Return;
    pub const XK_Tab = X.XK_Tab;
    pub const XK_comma = X.XK_comma;
    pub const XK_equal = X.XK_equal;
    pub const XK_minus = X.XK_minus;
    pub const XK_period = X.XK_period;
    pub const XK_space = X.XK_space;

    // AwesomeWM provides a very helpful graphic here:
    // https://awesomewm.org/doc/api/libraries/mouse.html

    /// Left click.
    pub const Button1 = X.Button1;
    /// Middle click.
    pub const Button2 = X.Button2;
    /// Right click.
    pub const Button3 = X.Button3;
    pub const Button4 = X.Button4;
    pub const Button5 = X.Button5;
};

// -----------------------------------------------------------------------------
// Errors
// -----------------------------------------------------------------------------

pub const err = struct {
    pub const BadAccess = X.BadAccess;
    pub const BadDrawable = X.BadDrawable;
    pub const BadGC = X.BadGC;
    pub const BadMatch = X.BadMatch;
};

////////////////////////////////////////////////////////////////////////////////
// Resources
// * https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html
// * https://x.org/releases/X11R7.7/doc/man/man3/
