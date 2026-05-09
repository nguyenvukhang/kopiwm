//! X Library functions with extra notes/docs attached.

const X = @import("c_lib.zig").X;

/// `fn(dpy: ?*Display, atom_name: [*c]const u8, only_if_exists: c_int) Atom`
///
/// The XInternAtom function returns the atom identifier associated with the
/// specified `atom_name`. If `only_if_exists` is False, the atom is created if
/// it does not exist. Therefore, `XInternAtom` can return a `None` Atom. If
/// the atom name is not in the Host Portable Character Encoding, the result is
/// implementation-dependent. Uppercase and lowercase matter. The atom will
/// remain defined even after the client's connection closes. It will become
/// undefined only when the last connection to the X server closes.
///
/// XInternAtom can generate BadAlloc and BadValue errors.
///
/// source: https://www.x.org/releases/X11R7.5/doc/man/man3/XInternAtom.3.html
pub const XInternAtom = X.XInternAtom;

/// The `Display` structure serves as the connection to the X server and that
/// contains all the information about that X server.
///
/// source: https://www.x.org/releases/X11R7.5/doc/man/man3/XOpenDisplay.3.html
pub const Display = X.Display;

pub const False = X.False;
pub const True = X.True;
