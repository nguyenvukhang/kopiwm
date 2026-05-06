const mem = @import("std").mem;

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
        pub inline fn get(self: *Self) []const u8 {
            return self.buffer[0..self.len];
        }

        /// Use memcpy to copy bytes from `value`.
        pub fn set(self: *Self, value: []const u8) void {
            self.len = @min(N, value.len);
            @memcpy(self.buffer[0..self.len], value[0..self.len]);
        }

        pub fn cstr(self: *Self) ?[*c]u8 {
            if (self.len < capacity) {
                self.buffer[self.len] = 0; // set the terminating NUL byte.
                return &self.buffer;
            }
            return null;
        }

        pub fn contains(self: *Self, substring: []const u8) bool {
            return mem.containsAtLeast(u8, self.get(), 1, substring);
        }
    };
}
