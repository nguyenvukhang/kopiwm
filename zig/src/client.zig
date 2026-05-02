const Monitor = @import("monitor.zig").Monitor;
const X = @import("c_lib.zig").X;
const Window = X.Window;

pub const Client = struct {
    const Self = @This();

    name: [256]u8,
    mina: f32,
    maxa: f32,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    oldx: i32,
    oldy: i32,
    oldw: i32,
    oldh: i32,
    basew: i32,
    baseh: i32,
    incw: i32,
    inch: i32,
    maxw: i32,
    maxh: i32,
    minw: i32,
    minh: i32,
    hintsvalid: bool,
    // Border width.
    bw: i32,
    // Old border width.
    oldbw: i32,
    // Bitmask of active tags.
    tags: u32,
    isfixed: bool,
    isfloating: bool,
    isurgent: bool,
    neverfocus: bool,
    // Old floating state (previous value for `isfloating`).
    oldstate: bool,
    isfullscreen: bool,
    // Next client in the linked list of clients.
    next: ?*Self,
    // Next client in the display stack.
    snext: ?*Self,
    mon: *Monitor,
    win: Window,
};
