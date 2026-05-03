const Monitor = @import("monitor.zig").Monitor;

/// [dwm] INTERSECT
fn intersect(x: i32, y: i32, w: i32, h: i32, m: *Monitor) i32 {
    return @max(0, @min(x + w, m.wx + @as(i32, @intCast(m.ww))) - @max(x, m.wx)) *
        @max(0, @min(y + h, m.wy + @as(i32, @intCast(m.wh))) - @max(y, m.wy));
}

pub const Rect = struct {
    const Self = @This();

    /// X-coordinate. Increases from left to right.
    x: i32,
    /// Y-coordinate. Increases from top to bottom.
    y: i32,
    /// Width.
    w: u32,
    /// Height.
    h: u32,

    pub const zero = Self{ .x = 0, .y = 0, .w = 0, .h = 0 };

    pub fn toMonitor(self: *const Self, default: ?*Monitor, mons: ?*Monitor) ?*Monitor {
        var r = default;
        var max_area: i32 = 0;
        var a: i32 = 0;
        var m_opt = mons;
        while (m_opt) |m| : (m_opt = m.next) {
            // TODO: make a rect-rect intersect method, and make a `toRect`
            // method for a monitor.
            a = intersect(self.x, self.y, @intCast(self.w), @intCast(self.h), m);
            if (a > max_area) {
                max_area = a;
                r = m;
            }
        }
        return r;
    }
};
