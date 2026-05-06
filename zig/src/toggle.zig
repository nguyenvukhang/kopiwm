pub fn toggle(comptime T: type) type {
    return struct {
        const Self = @This();
        /// The value right now.
        now: T,
        /// Previous value.
        prev: T,

        pub fn init(value: T) Self {
            return .{ .now = value, .prev = value };
        }

        pub fn set(self: *Self, value: T) void {
            self.prev = self.now;
            self.now = value;
        }

        /// Revert the nowent state to the previous state.
        pub fn revert(self: *Self) void {
            self.now = self.prev;
        }
    };
}
