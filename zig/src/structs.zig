const x = @import("c_lib.zig").x;

pub const Display = x.Display;
pub const Cursor = x.Cursor;

// TODO: change this to Font when all is said and done.
pub const Fnt = struct { dpy: ?*Display, h: u16, xfont: ?*x.XftFont };
