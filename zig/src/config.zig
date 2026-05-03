const std = @import("std");
const X = @import("c_lib.zig").X;
const lt = @import("layout.zig");
const SchemeState = @import("enums.zig").SchemeState;
const N = @import("enums.zig").N;
const Scheme = @import("drw.zig").Scheme;
const EnumArray = std.enums.EnumArray;
const Arg = @import("enums.zig").Arg;
const Key = @import("enums.zig").Key;

pub const tags = [_][]const u8{ "1", "2", "3", "4", "T" };
pub const fonts = [_][]const u8{"monospace:size=10"};

/// Factor of the master area size [0.05...0.95].
pub const mfact: f32 = 0.5;

/// Number of clients in master area
pub const nmaster = 1;

/// 1 means respect size hints in tiled resizals
pub const resizehints = 1;

/// 1 will force focus on the fullscreen window
pub const lockfullscreen = 1;

/// refresh rate (per second) for client move/resize
pub const refreshrate = 60;

// false means hide bar.
pub const show_bar = true;

// false means bottom bar.
pub const top_bar = true;

pub const layouts = [_]lt.Layout{
    .{ .symbol = "[]=", .arrange = lt.tile },
    .{ .symbol = "[M]", .arrange = lt.monocle },
};

const col_gray1: []const u8 = "#222222";
const col_gray2: []const u8 = "#444444";
const col_gray3: []const u8 = "#bbbbbb";
const col_gray4: []const u8 = "#eeeeee";
const col_accent_400: []const u8 = "#d8b4fe";
const col_accent_900: []const u8 = "#581c87";

pub const colors = EnumArray(SchemeState, Scheme([]const u8)).init(.{
    // As of the time of writing, LSP doesn't quite work here in terms of
    // suggesting the `SchemeState` as the keys. It will still catch nicely at
    // comptime though.
    //
    // zig fmt: off
    .Normal   = .{ .fg = col_gray3, .bg = col_gray1,      .border = col_gray2      },
    .Selected = .{ .fg = col_gray1, .bg = col_accent_400, .border = col_accent_900 },
    .Bar      = .{ .fg = col_gray3, .bg = col_gray2,      .border = col_gray2      },
    // zig fmt: on
});

const Mod4Mask = 1 << 4;
const MODKEY = Mod4Mask;
pub const keys = [_]Key{
    .{ .mod = MODKEY, .key = X.XK_space, .func = undefined, .arg = undefined },
};
