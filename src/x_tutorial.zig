//! X Library functions with extra notes/docs attached.
//!
//! https://x.org/releases/X11R7.7/doc/man/man3/

const X = @import("c_lib.zig").X;
const Coordinates = @import("enums.zig").Coordinates;

// -----------------------------------------------------------------------------
// XID aliases
// -----------------------------------------------------------------------------

/// See the XC_* defines in X11. The usual cursor would be `XC_left_ptr`.
pub const Cursor = X.Cursor;
pub const Drawable = X.Drawable;
pub const KeySym = X.KeySym;
/// To specify a null state, use `None`.
pub const Window = X.Window;

// -----------------------------------------------------------------------------
// Integer type aliases
// -----------------------------------------------------------------------------

pub const Time = X.Time;

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

/// When you receive this event, the structure members are set as follows.
///
/// The type member is set to the event type constant name that uniquely
/// identifies it. For example, when the X server reports a GraphicsExpose
/// event to a client application, it sends an XGraphicsExposeEvent structure
/// with the type member set to GraphicsExpose. The display member is set to a
/// pointer to the display the event was read on. The send_event member is set
/// to True if the event came from a SendEvent protocol request. The serial
/// member is set from the serial number reported in the protocol but expanded
/// from the 16-bit least-significant bits to a full 32-bit value. The window
/// member is set to the window that is most useful to toolkit dispatchers.
///
/// The event member is set either to the reconfigured window or to its parent,
/// depending on whether StructureNotify or SubstructureNotify was selected.
/// The window member is set to the window whose size, position, border, and/or
/// stacking order was changed.
///
/// The x and y members are set to the coordinates relative to the parent
/// window's origin and indicate the position of the upper-left outside corner
/// of the window. The width and height members are set to the inside size of
/// the window, not including the border. The border_width member is set to the
/// width of the window's border, in pixels.
///
/// The above member is set to the sibling window and is used for stacking
/// operations. If the X server sets this member to None, the window whose
/// state was changed is on the bottom of the stack with respect to sibling
/// windows. However, if this member is set to a sibling window, the window
/// whose state was changed is placed on top of this sibling window.
///
/// The override_redirect member is set to the override-redirect attribute of
/// the window. Window manager clients normally should ignore this window if
/// the override_redirect member is True.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XConfigureEvent.3.xhtml
pub const XConfigureEvent = X.XConfigureEvent;

/// When you receive this event, the structure members are set as follows.
///
/// The serial member is the number of requests, starting from one, sent over
/// the network connection since it was opened. It is the number that was the
/// value of NextRequest immediately before the failing call was made. The
/// request_code member is a protocol request of the procedure that failed, as
/// defined in <X11/Xproto.h>.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XErrorEvent.3.xhtml
pub const XErrorEvent = X.XErrorEvent;

/// An XEvent structure's first entry always is the type member, which is set
/// to the event type. The second member always is the serial number of the
/// protocol request that generated the event. The third member always is
/// send_event, which is a Bool that indicates if the event was sent by a
/// different client. The fourth member always is a display, which is the
/// display that the event was read from. Except for keymap events, the fifth
/// member always is a window, which has been carefully selected to be useful
/// to toolkit dispatchers. To avoid breaking toolkits, the order of these
/// first five entries is not to change. Most events also contain a time
/// member, which is the time at which an event occurred. In addition, a
/// pointer to the generic event must be cast before it is used to access any
/// other information in the structure.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XAnyEvent.3.xhtml
pub const XEvent = X.XEvent;

/// The XModifierKeymap structure contains:
///
/// ```c
/// typedef struct {
///     int max_keypermod; /* This server's max number of keys per modifier */
///     KeyCode *modifiermap; /* An 8 by max_keypermod array of the modifiers */
/// } XModifierKeymap;
/// ```
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XChangeKeyboardMapping.3.xhtml
pub const XModifierKeymap = X.XModifierKeymap;

/// The XSetWindowAttributes structure contains:
///
/// ```c
/// typedef struct {
///     Pixmap background_pixmap;/* background, None, or ParentRelative */
///     unsigned long background_pixel;/* background pixel */
///     Pixmap border_pixmap; /* border of the window or CopyFromParent */
///     unsigned long border_pixel;/* border pixel value */
///     int bit_gravity; /* one of bit gravity values */
///     int win_gravity; /* one of the window gravity values */
///     int backing_store; /* NotUseful, WhenMapped, Always */
///     unsigned long backing_planes;/* planes to be preserved if possible */
///     unsigned long backing_pixel;/* value to use in restoring planes */
///     Bool save_under; /* should bits under be saved? (popups) */
///     long event_mask; /* set of events that should be saved */
///     long do_not_propagate_mask;/* set of events that should not propagate */
///     Bool override_redirect; /* boolean value for override_redirect */
///     Colormap colormap; /* color map to be associated with window */
///     Cursor cursor; /* cursor to be displayed (or None) */
/// } XSetWindowAttributes;
/// ```
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XCreateWindow.3.xhtml
pub const XSetWindowAttributes = X.XSetWindowAttributes;

/// The XTextProperty structure contains:
/// ```c
/// typedef struct {
///     unsigned char *value; /* property data */
///     Atom encoding;        /* type of property */
///     int format;           /* 8, 16, or 32 */
///     unsigned long nitems; /* number of items in value */
/// } XTextProperty;
/// ```
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XStringListToTextProperty.3.xhtml
pub const XTextProperty = X.XTextProperty;

/// The XWindowAttributes structure contains:
///
/// ```c
/// typedef struct {
///     int x, y; /* location of window */
///     int width, height; /* width and height of window */
///     int border_width; /* border width of window */
///     int depth; /* depth of window */
///     Visual *visual; /* the associated visual structure */
///     Window root; /* root of screen containing window */
///     int class; /* InputOutput, InputOnly*/
///     int bit_gravity; /* one of the bit gravity values */
///     int win_gravity; /* one of the window gravity values */
///     int backing_store; /* NotUseful, WhenMapped, Always */
///     unsigned long backing_planes;/* planes to be preserved if possible */
///     unsigned long backing_pixel;/* value to be used when restoring planes */
///     Bool save_under; /* boolean, should bits under be saved? */
///     Colormap colormap; /* color map to be associated with window */
///     Bool map_installed; /* boolean, is color map currently installed*/
///     int map_state; /* IsUnmapped, IsUnviewable, IsViewable */
///     long all_event_masks; /* set of events all people have interest in*/
///     long your_event_mask; /* my event mask */
///     long do_not_propagate_mask;/* set of events that should not propagate */
///     Bool override_redirect; /* boolean value for override-redirect */
///     Screen *screen; /* back pointer to correct screen */
/// } XWindowAttributes;
/// ```
///
/// The x and y members are set to the upper-left outer corner relative to the
/// parent window's origin. The width and height members are set to the inside
/// size of the window, not including the border. The border_width member is
/// set to the window's border width in pixels. The depth member is set to the
/// depth of the window (that is, bits per pixel for the object). The visual
/// member is a pointer to the screen's associated Visual structure. The root
/// member is set to the root window of the screen containing the window. The
/// class member is set to the window's class and can be either InputOutput or
/// InputOnly.
///
/// For additional information on gravity, see section 3.3.
///
/// The backing_store member is set to indicate how the X server should
/// maintain the contents of a window and can be WhenMapped, Always, or
/// NotUseful. The backing_planes member is set to indicate (with bits set to
/// 1) which bit planes of the window hold dynamic data that must be preserved
/// in backing_stores and during save_unders. The backing_pixel member is set
/// to indicate what values to use for planes not set in backing_planes.
///
/// The save_under member is set to True or False. The colormap member is set
/// to the colormap for the specified window and can be a colormap ID or None.
/// The map_installed member is set to indicate whether the colormap is
/// currently installed and can be True or False. The map_state member is set
/// to indicate the state of the window and can be IsUnmapped, IsUnviewable, or
/// IsViewable. IsUnviewable is used if the window is mapped but some ancestor
/// is unmapped.
///
/// The all_event_masks member is set to the bitwise inclusive OR of all event
/// masks selected on the window by all clients. The your_event_mask member is
/// set to the bitwise inclusive OR of all event masks selected by the querying
/// client. The do_not_propagate_mask member is set to the bitwise inclusive OR
/// of the set of events that should not propagate.
///
/// The override_redirect member is set to indicate whether this window
/// overrides structure control facilities and can be True or False. Window
/// manager clients should ignore the window if this member is True.
///
/// The screen member is set to a screen pointer that gives you a back pointer
/// to the correct screen. This makes it easier to obtain the screen
/// information without having to loop over the root window fields to see which
/// field matches.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGetWindowAttributes.3.xhtml
pub const XWindowAttributes = X.XWindowAttributes;

/// An XftColor object permits text and other items to be rendered in a
/// particular color (or the closest approximation offered by the X visual in
/// use). The XRenderColor data type is defined by the X Render Extension
/// library.
///
/// XftColorAllocName() and XftColorAllocValue() request a color allocation
/// from the X server (if necessary) and initialize the members of XftColor.
/// XftColorFree() instructs the X server to free the color currently allocated
/// for an XftColor.
///
/// One an XftColor has been initialized, XftDrawSrcPicture(), XftDrawGlyphs(),
/// the XftDrawString*() family, XftDrawCharSpec(), XftDrawCharFontSpec(),
/// XftDrawGlyphSpec(), XftDrawGlyphFontSpec(), and XftDrawRect() may be used
/// to draw various objects using it.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/Xft.3.xhtml
pub const XftColor = X.XftColor;

/// An XftFont is the primary data structure of interest to programmers using
/// Xft; it contains general font metrics and pointers to the Fontconfig
/// character set and pattern associated with the font. The FcCharSet and
/// FcPattern data types are defined by the Fontconfig library.
///
/// XftFonts are populated with any of XftFontOpen(), XftFontOpenName(),
/// XftFontOpenXlfd(), XftFontOpenInfo(), or XftFontOpenPattern().
/// XftFontCopy() is used to duplicate XftFonts, and XftFontClose() is used to
/// mark an XftFont as unused. XftFonts are internally allocated,
/// reference-counted, and freed by Xft; the programmer does not ordinarily
/// need to allocate or free storage for them.
///
/// XftDrawGlyphs(), the XftDrawString*() family, XftDrawCharSpec(), and
/// XftDrawGlyphSpec() use XftFonts to render text to an XftDraw object, which
/// may correspond to either a core X drawable or an X Rendering Extension
/// drawable.
///
/// XftGlyphExtents() and the XftTextExtents*() family are used to determine
/// the extents (maximum dimensions) of an XftFont.
///
/// An XftFont's glyph or character coverage can be determined with
/// XftFontCheckGlyph() or XftCharExists(). XftCharIndex() returns the
/// XftFont-specific character index corresponding to a given Unicode
/// codepoint.
///
/// XftGlyphRender(), XftGlyphSpecRender(), XftCharSpecRender(), and the
/// XftTextRender*() family use XftFonts to draw into X Rendering Extension
/// Picture structures. Note: XftDrawGlyphs(), the XftDrawString*() family,
/// XftDrawCharSpec(), and XftDrawGlyphSpec() provide a means of rendering
/// fonts that is independent of the availability of the X Rendering Extension
/// on the X server.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/Xft.3.xhtml
pub const XftFont = X.XftFont;

// -----------------------------------------------------------------------------
// Functions
// -----------------------------------------------------------------------------

/// The XChangeProperty function alters the property for the specified window
/// and causes the X server to generate a PropertyNotify event on that window.
/// XChangeProperty performs the following:
///
/// * If mode is PropModeReplace, XChangeProperty discards the previous
///   property value and stores the new data.
///
/// * If mode is PropModePrepend or PropModeAppend, XChangeProperty inserts the
///   specified data before the beginning of the existing data or onto the end
///   of the existing data, respectively. The type and format must match the
///   existing property value, or a BadMatch error results. If the property is
///   undefined, it is treated as defined with the correct type and format with
///   zero-length data.
///
/// If the specified format is 8, the property data must be a char array. If
/// the specified format is 16, the property data must be a short array. If the
/// specified format is 32, the property data must be a long array.
///
/// The lifetime of a property is not tied to the storing client. Properties
/// remain until explicitly deleted, until the window is destroyed, or until
/// the server resets. For a discussion of what happens when the connection to
/// the X server is closed, see section 2.6. The maximum size of a property is
/// server dependent and can vary dynamically depending on the amount of memory
/// the server has available. (If there is insufficient space, a BadAlloc error
/// results.)
///
/// XChangeProperty can generate BadAlloc, BadAtom, BadMatch, BadValue, and
/// BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGetWindowProperty.3.xhtml
pub inline fn XChangeProperty(
    display: *Display,
    window: Window,
    property: Atom,
    p_type: Atom,
    format: c_int,
    mode: PropMode,
    data: [*c]const u8,
    nelements: c_int,
) void {
    // Meaning of return value is not specified in documentation.
    _ = X.XChangeProperty(
        display,
        window,
        property,
        p_type,
        format,
        @intFromEnum(mode),
        data,
        nelements,
    );
}

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
    display: *Display,
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

/// The XFree function is a general-purpose Xlib routine that frees the
/// specified data. You must use it to free any objects that were allocated by
/// Xlib, unless an alternate function is explicitly specified for the object.
/// A NULL pointer cannot be passed to this function.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XFree.3.xhtml
pub inline fn XFree(ptr: ?*anyopaque) void {
    // The meaning of the return value was not specified in documentation.
    _ = X.XFree(ptr);
}

/// The XFreeModifiermap function frees the specified XModifierKeymap structure.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XChangeKeyboardMapping.3.xhtml
pub inline fn XFreeModifiermap(modmap: [*c]X.XModifierKeymap) void {
    X.XFreeModifiermap(modmap);
}

/// The XFreeStringList function releases memory allocated by
/// XmbTextPropertyToTextList, Xutf8TextPropertyToTextList and
/// XTextPropertyToStringList and the missing charset list allocated by
/// XCreateFontSet.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XStringListToTextProperty.3.xhtml
pub inline fn XFreeStringList(list: [*c][*c]u8) void {
    X.XFreeStringList(list);
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
    display: *Display,
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

/// The XGrabButton function establishes a passive grab. In the future, the
/// pointer is actively grabbed (as for XGrabPointer), the last-pointer-grab
/// time is set to the time at which the button was pressed (as transmitted in
/// the ButtonPress event), and the ButtonPress event is reported if all of the
/// following conditions are true:
///
/// 1. The pointer is not grabbed, and the specified button is logically pressed
///    when the specified modifier keys are logically down, and no other buttons
///    or modifier keys are logically down.
/// 2. The grab_window contains the pointer.
/// 3. The confine_to window (if any) is viewable.
/// 4. A passive grab on the same button/key combination does not exist on any
///    ancestor of grab_window.
///
/// The interpretation of the remaining arguments is as for XGrabPointer. The
/// active grab is terminated automatically when the logical state of the
/// pointer has all buttons released (independent of the state of the logical
/// modifier keys), at which point a ButtonRelease event is reported to the
/// grabbing window.
///
/// Note that the logical state of a device (as seen by client applications)
/// may lag the physical state if device event processing is frozen.
///
/// This request overrides all previous grabs by the same client on the same
/// button/key combinations on the same window. A modifiers of AnyModifier is
/// equivalent to issuing the grab request for all possible modifier
/// combinations (including the combination of no modifiers). It is not
/// required that all modifiers specified have currently assigned KeyCodes. A
/// button of AnyButton is equivalent to issuing the request for all possible
/// buttons. Otherwise, it is not required that the specified button currently
/// be assigned to a physical button.
///
/// If some other client has already issued a XGrabButton with the same
/// button/key combination on the same window, a BadAccess error results. When
/// using AnyModifier or AnyButton, the request fails completely, and a
/// BadAccess error results (no grabs are established) if there is a
/// conflicting grab for any combination. XGrabButton has no effect on an
/// active grab.
///
/// XGrabButton can generate BadCursor, BadValue, and BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGrabButton.3.xhtml
pub inline fn XGrabButton(
    display: *Display,
    /// Specifies the pointer button that is to be grabbed or released or AnyButton.
    button: c_uint,
    modifiers: c_uint,
    grab_window: Window,
    owner_events: bool,
    event_mask: c_uint,
    pointer_mode: GrabMode,
    keyboard_mode: GrabMode,
    confine_to: Window,
    cursor: Cursor,
) void {
    // Inferrably, since XGrabButton is very similar to XGrabPointer, the
    // returned integer could mean X.GrabSuccess. However, since it's not
    // explicitly stated in the documentation, we shall discard it.
    _ = X.XGrabButton(
        display,
        button,
        modifiers,
        grab_window,
        @intFromBool(owner_events),
        event_mask,
        @intFromEnum(pointer_mode),
        @intFromEnum(keyboard_mode),
        confine_to,
        cursor,
    );
}

/// The XGrabPointer function actively grabs control of the pointer and returns
/// true if the grab was successful. Further pointer events are reported only
/// to the grabbing client. XGrabPointer overrides any active pointer grab by
/// this client. If owner_events is False, all generated pointer events are
/// reported with respect to grab_window and are reported only if selected by
/// event_mask. If owner_events is True and if a generated pointer event would
/// normally be reported to this client, it is reported as usual. Otherwise,
/// the event is reported with respect to the grab_window and is reported only
/// if selected by event_mask. For either value of owner_events, unreported
/// events are discarded.
///
/// XGrabPointer generates EnterNotify and LeaveNotify events.
///
/// Either if grab_window or confine_to window is not viewable or if the
/// confine_to window lies completely outside the boundaries of the root
/// window, XGrabPointer fails and returns GrabNotViewable. If the pointer is
/// actively grabbed by some other client, it fails and returns AlreadyGrabbed.
/// If the pointer is frozen by an active grab of another client, it fails and
/// returns GrabFrozen. If the specified time is earlier than the
/// last-pointer-grab time or later than the current X server time, it fails
/// and returns GrabInvalidTime. Otherwise, the last-pointer-grab time is set
/// to the specified time (CurrentTime is replaced by the current X server
/// time).
///
/// XGrabPointer can generate BadCursor, BadValue, and BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGrabPointer.3.xhtml
pub inline fn XGrabPointer(
    display: *Display,
    grab_window: Window,
    owner_events: bool,
    event_mask: c_uint,
    /// If it's GrabModeAsync, pointer event processing continues as usual. If
    /// the pointer is currently frozen by this client, the processing of
    /// events for the pointer is resumed. If the pointer_mode is GrabModeSync,
    /// the state of the pointer, as seen by client applications, appears to
    /// freeze, and the X server generates no further pointer events until the
    /// grabbing client calls XAllowEvents or until the pointer grab is
    /// released. Actual pointer changes are not lost while the pointer is
    /// frozen; they are simply queued in the server for later processing.
    pointer_mode: GrabMode,
    /// If it's GrabModeAsync, keyboard event processing is unaffected by
    /// activation of the grab. If the keyboard_mode is GrabModeSync, the state
    /// of the keyboard, as seen by client applications, appears to freeze, and
    /// the X server generates no further keyboard events until the grabbing
    /// client calls XAllowEvents or until the pointer grab is released. Actual
    /// keyboard changes are not lost while the pointer is frozen; they are
    /// simply queued in the server for later processing.
    keyboard_mode: GrabMode,
    /// If a confine_to window is specified, the pointer is restricted to stay
    /// contained in that window. The confine_to window need have no
    /// relationship to the grab_window. If the pointer is not initially in the
    /// confine_to window, it is warped automatically to the closest edge just
    /// before the grab activates and enter/leave events are generated as
    /// usual. If the confine_to window is subsequently reconfigured, the
    /// pointer is warped automatically, as necessary, to keep it contained in
    /// the window.
    confine_to: Window,
    /// If a cursor is specified, it is displayed regardless of what window the
    /// pointer is in. If None is specified, the normal cursor for that window
    /// is displayed when the pointer is in grab_window or one of its
    /// subwindows; otherwise, the cursor for grab_window is displayed.
    cursor: Cursor,
    /// The time argument allows you to avoid certain circumstances that come
    /// up if applications take a long time to respond or if there are long
    /// network delays. Consider a situation where you have two applications,
    /// both of which normally grab the pointer when clicked on. If both
    /// applications specify the timestamp from the event, the second
    /// application may wake up faster and successfully grab the pointer before
    /// the first application. The first application then will get an
    /// indication that the other application grabbed the pointer before its
    /// request was processed.
    time: Time,
) bool {
    const result = X.XGrabPointer(
        display,
        grab_window,
        @intFromBool(owner_events),
        event_mask,
        @intFromEnum(pointer_mode),
        @intFromEnum(keyboard_mode),
        confine_to,
        cursor,
        time,
    );
    // From the docs:
    // "The XGrabPointer function actively grabs control of the pointer and
    // returns GrabSuccess if the grab was successful."
    return result == X.GrabSuccess;
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
    display: *Display,
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

/// The XMoveResizeWindow function changes the size and location of the
/// specified window without raising it. Moving and resizing a mapped window
/// may generate an Expose event on the window. Depending on the new size and
/// location parameters, moving and resizing a window may generate Expose
/// events on windows that the window formerly obscured.
///
/// If the override-redirect flag of the window is False and some other client
/// has selected SubstructureRedirectMask on the parent, the X server generates
/// a ConfigureRequest event, and no further processing is performed.
/// Otherwise, the window size and location are changed.
///
/// XMoveResizeWindow can generate BadValue and BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XConfigureWindow.3.xhtml
pub inline fn XMoveResizeWindow(
    display: *Display,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
) void {
    // It is not specified in documentation what the return value of XMoveWindow
    // is, so we shall discard it.
    _ = X.XMoveResizeWindow(display, window, x, y, width, height);
}

/// The XMoveWindow function moves the specified window to the specified x and
/// y coordinates, but it does not change the window's size, raise the window,
/// or change the mapping state of the window. Moving a mapped window may or
/// may not lose the window's contents depending on if the window is obscured
/// by nonchildren and if no backing store exists. If the contents of the
/// window are lost, the X server generates Expose events. Moving a mapped
/// window generates Expose events on any formerly obscured windows.
///
/// If the override-redirect flag of the window is False and some other client
/// has selected SubstructureRedirectMask on the parent, the X server generates
/// a ConfigureRequest event, and no further processing is performed.
/// Otherwise, the window is moved.
///
/// XMoveWindow can generate a BadWindow error.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XConfigureWindow.3.xhtml
pub inline fn XMoveWindow(
    display: *Display,
    window: Window,
    x: c_int,
    y: c_int,
) void {
    // The x and y coordinates are the new location of the top-left pixel of
    // the window's border or the window itself if it has no border or define
    // the new position of the window relative to its parent.

    // It is not specified in documentation what the return value of XMoveWindow
    // is, so we shall discard it.
    _ = X.XMoveWindow(display, window, x, y);
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

/// Custom struct for dealing with XQueryPointer.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XQueryPointer.3.xhtml
pub const XQueryPointerResult = struct {
    /// The root window the pointer is logically on.
    root_window: Window,
    /// The coordinates of the pointer relative to the root window's origin.
    root_pos: Coordinates(c_int),
    /// This is non-null if and only if the pointer is on the same screen as the
    /// specified window. It is the coordinates of the cursor relative to the
    /// origin of the specified window.
    win_pos: ?Coordinates(c_int),
    /// Returns the child window that the pointer is located in, if any.
    child: ?Window,
    /// The current logical state of the keyboard buttons and the modifier
    /// keys. That is, the bitwise inclusive OR of one or more of the button or
    /// modifier key bitmasks to match the current state of the mouse buttons
    /// and the modifier keys.
    mask: c_uint,
};

/// The XQueryPointer function returns the root window the pointer is logically
/// on and the pointer coordinates relative to the root window's origin. If
/// XQueryPointer returns False, the pointer is not on the same screen as the
/// specified window, and XQueryPointer returns None to child_return and zero
/// to win_x_return and win_y_return. If XQueryPointer returns True, the
/// pointer coordinates returned to win_x_return and win_y_return are relative
/// to the origin of the specified window. In this case, XQueryPointer returns
/// the child that contains the pointer, if any, or else None to child_return.
///
/// XQueryPointer returns the current logical state of the keyboard buttons and
/// the modifier keys in mask_return. It sets mask_return to the bitwise
/// inclusive OR of one or more of the button or modifier key bitmasks to match
/// the current state of the mouse buttons and the modifier keys.
///
/// XQueryPointer can generate a BadWindow error.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XQueryPointer.3.xhtml
pub inline fn XQueryPointer(
    display: *Display,
    window: Window,
) XQueryPointerResult {
    var r: XQueryPointerResult = .{
        .root_window = undefined,
        .root_pos = .zero,
        .win_pos = .zero,
        .child = 0,
        .mask = undefined,
    };
    // Bool XQueryPointer(Display *display, Window w,
    //                    Window *root_return,
    //                    Window *child_return,
    //                    int *root_x_return,
    //                    int *root_y_return,
    //                    int *win_x_return,
    //                    int *win_y_return,
    //                    unsigned int *mask_return);
    const result = X.XQueryPointer(display, window, &r.root_window, &r.child.?, //
        &r.root_pos.x, &r.root_pos.y, &r.win_pos.?.x, &r.win_pos.?.y, &r.mask);
    if (result == 0) {
        // If XQueryPointer returns False, the pointer is not on the same
        // screen as the specified window, and XQueryPointer returns None to
        // child_return and zero to win_x_return and win_y_return.
        r.child = null;
        r.win_pos = null;
    } else {
        // If XQueryPointer returns True, the pointer coordinates returned to
        // win_x_return and win_y_return are relative to the origin of the
        // specified window. In this case, XQueryPointer returns the child that
        // contains the pointer, if any, or else None to child_return.
        if (r.child == X.None) r.child = null;
    }
    return r;
}

/// The XGetTextProperty function reads the specified property from the window
/// and stores the data in the returned XTextProperty structure. It stores the
/// data in the value field, the type of the data in the encoding field, the
/// format of the data in the format field, and the number of items of data in
/// the nitems field. An extra byte containing null (which is not included in
/// the nitems member) is stored at the end of the value field of
/// text_prop_return. The particular interpretation of the property's encoding
/// and data as text is left to the calling application. If the specified
/// property does not exist on the window, XGetTextProperty sets the value
/// field to NULL, the encoding field to None, the format field to zero, and
/// the nitems field to zero.
///
/// If it was able to read and store the data in the XTextProperty structure,
/// XGetTextProperty returns a nonzero status; otherwise, it returns a zero
/// status.
///
/// XGetTextProperty can generate BadAtom and BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XSetTextProperty.3.xhtml
pub inline fn XGetTextProperty(
    display: *Display,
    window: Window,
    property: Atom,
) ?XTextProperty {
    var ret: XTextProperty = undefined;
    const status = X.XGetTextProperty(display, window, &ret, property);
    return if (status == 0) null else ret;
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
pub inline fn XSync(display: *Display, discard: bool) void {
    // According to the docs in the source, the c_int output is only important
    // in the other functions documented on that html page, but not XSync. So
    // we discard it.
    _ = X.XSync(display, @intFromBool(discard));
}

/// The XUngrabButton function releases the passive button/key combination on
/// the specified window if it was grabbed by this client. A modifiers of
/// AnyModifier is equivalent to issuing the ungrab request for all possible
/// modifier combinations, including the combination of no modifiers. A button
/// of AnyButton is equivalent to issuing the request for all possible buttons.
/// XUngrabButton has no effect on an active grab.
///
/// XUngrabButton can generate BadValue and BadWindow errors.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGrabButton.3.xhtml
pub inline fn XUngrabButton(
    display: *Display,
    /// Specifies the pointer button that is to be grabbed or released or
    /// AnyButton.
    button: c_uint,
    /// Specifies the set of keymasks or AnyModifier. The mask is the bitwise
    /// inclusive OR of the valid keymask bits.
    modifiers: c_uint,
    grab_window: Window,
) void {
    // According to the docs, the return value is not used.
    _ = X.XUngrabButton(display, button, modifiers, grab_window);
}

/// The XUngrabPointer function releases the pointer and any queued events if
/// this client has actively grabbed the pointer from XGrabPointer,
/// XGrabButton, or from a normal button press. XUngrabPointer does not release
/// the pointer if the specified time is earlier than the last-pointer-grab
/// time or is later than the current X server time. It also generates
/// EnterNotify and LeaveNotify events. The X server performs an UngrabPointer
/// request automatically if the event window or confine_to window for an
/// active pointer grab becomes not viewable or if window reconfiguration
/// causes the confine_to window to lie completely outside the boundaries of
/// the root window.
///
/// source: https://x.org/releases/X11R7.7/doc/man/man3/XGrabPointer.3.xhtml
pub inline fn XUngrabPointer(display: *Display, time: Time) void {
    // According to the docs, the return value is not used.
    _ = X.XUngrabPointer(display, time);
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
pub inline fn XUnmapWindow(display: *Display, window: Window) c_int {
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

pub const GrabMode = enum(c_int) {
    Sync = X.GrabModeSync,
    Async = X.GrabModeAsync,
};

pub const PropMode = enum(c_int) {
    Replace = X.PropModeReplace,
    Prepend = X.PropModePrepend,
    Append = X.PropModeAppend,
};

////////////////////////////////////////////////////////////////////////////////
// Resources
// * https://x.org/releases/X11R7.7/doc/xproto/x11protocol.html
// * https://x.org/releases/X11R7.7/doc/man/man3/
