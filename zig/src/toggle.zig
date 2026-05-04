pub fn toggle(comptime T: type) type {
    return struct {
        const Self = @This();
        /// Current value.
        curr: T,
        /// Previous value.
        prev: T,

        pub fn init(value: T) Self {
            return .{ .curr = value, .prev = value };
        }

        pub fn set(self: *Self, value: T) void {
            self.prev = self.curr;
            self.curr = value;
        }
    };
}
