const Monitor = @import("monitor.zig").Monitor;

pub const Layout = struct {
    symbol: []const u8,
    arrange: *fn (*Monitor) void,
};
