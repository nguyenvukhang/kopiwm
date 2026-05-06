const std = @import("std");

/// A simpler EnumArray, just because. `Key` has to be an enum.
pub fn EnumArray(comptime Key: type, comptime Value: type) type {
    return struct {
        const Self = @This();

        values: [std.enums.values(Key).len]Value,

        pub inline fn get(self: *const Self, key: Key) Value {
            return self.values[@intFromEnum(key)];
        }

        pub inline fn getPtr(self: *Self, key: Key) *Value {
            return &self.values[@intFromEnum(key)];
        }

        pub inline fn set(self: *Self, key: Key, value: Value) void {
            self.values[@intFromEnum(key)] = value;
        }
    };
}
