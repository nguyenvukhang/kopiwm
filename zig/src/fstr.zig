/// A string with a fixed-sized buffer underneath.
pub fn fstr(comptime N: usize) type {
    return struct {
        const Self = @This();
        pub const capacity: usize = N;

        /// Do not access this directly if possible.
        buffer: [N]u8 = undefined,
        /// Do not access this directly if possible.
        len: usize = 0,

        /// Gets the underlying string representation.
        pub fn get(self: *Self) []const u8 {
            return self.buffer[0..self.len];
        }

        /// Use memcpy to copy bytes from `value`.
        pub fn set(self: *Self, value: []const u8) void {
            self.len = @min(N, value.len);
            @memcpy(self.buffer[0..self.len], value[0..self.len]);
        }
    };
}
