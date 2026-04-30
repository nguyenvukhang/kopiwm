// Some tests to see how C strings interact with Zig code.
const std = @import("std");

const small = @cImport({
    @cInclude("small.c");
});

test "c null char*" {
    const value: [*c]u8 = small.get_null_str();
    try std.testing.expect(value == null);
}

test "c nonnull char*" {
    const value: [*c]u8 = small.get_nonnull_str();
    try std.testing.expect(value != null);
    const parsed: []const u8 = std.mem.span(value);
    try std.testing.expect(std.mem.eql(u8, parsed, "the once was a ship that put to sea"));
}
