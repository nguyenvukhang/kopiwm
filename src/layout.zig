const Monitor = @import("monitor.zig").Monitor;

pub const Layout = struct {
    const Self = @This();
    symbol: []const u8,
    arrange: ?*const fn (*Monitor) void,

    pub const empty: Self = .{ .symbol = "><>", .arrange = null };
};
