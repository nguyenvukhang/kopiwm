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

test "c coerce optional ptr" {
    const value: ?*u8 = small.get_null_str();
    try std.testing.expect(value == null);
}

test "c coerce nonnull optional ptr" {
    const value: ?*u8 = small.get_nonnull_str();
    try std.testing.expect(value != null);
}

test "string 1" {
    const value: ?[*]const u8 = small.get_null_str();
    try std.testing.expect(value == null);
}

test "string 2" {
    const value: [*]const u8 = small.get_null_str() orelse "hey";
    try std.testing.expect(value[0] == 'h');
}

test "string 3" {
    const value: []const u8 = std.mem.span(small.get_nonnull_str());
    try std.testing.expect(value[0] == 't');
}
