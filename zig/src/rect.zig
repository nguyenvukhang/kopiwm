const Monitor = @import("monitor.zig").Monitor;
const X = @import("c_lib.zig").X;

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

    /// Translate from this to an X11 struct. Use keys [x, y, width, height].
    pub fn toX(self: *const Self, comptime T: type) T {
        var t: T = undefined;
        t.x = @intCast(self.x);
        t.y = @intCast(self.y);
        t.width = @intCast(self.w);
        t.height = @intCast(self.h);
        return t;
    }

    /// Translate from an X11 struct to this. Use keys [x, y, width, height].
    pub fn fromX(comptime T: type, z: *T) Self {
        return .{ .x = @intCast(z.x), .y = @intCast(z.y), .w = @intCast(z.width), .h = @intCast(z.height) };
    }

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

    pub fn eq(lhs: *const Self, rhs: *const Self) bool {
        return lhs.x == rhs.x and lhs.y == rhs.y and lhs.w == rhs.w and lhs.h == rhs.h;
    }
};
