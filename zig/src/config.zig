const Layout = @import("layout.zig").Layout;

pub const fonts = [1][]const u8{"monospace:size=10"};

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

pub const layouts = [2]Layout{
    .{ .symbol = "[]=" },
    .{ .symbol = "[M]" },
};
