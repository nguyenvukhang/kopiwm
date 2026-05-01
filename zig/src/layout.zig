const Monitor = @import("monitor.zig").Monitor;

pub const Layout = struct {
    symbol: []const u8,
    arrange: *fn (*Monitor) void,
};

pub fn tile(m: *Monitor) void {
    _ = m;
}

pub fn monocle(m: *Monitor) void {
    _ = m;
}
