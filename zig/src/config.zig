const std = @import("std");
const X = @import("c_lib.zig").X;
const lt = @import("layout.zig");
const SchemeState = @import("enums.zig").SchemeState;
const N = @import("enums.zig").N;
const Scheme = @import("drw.zig").Scheme;
const EnumArray = @import("enum_array.zig").EnumArray;
const Arg = @import("enums.zig").Arg;
const BarPosition = @import("enums.zig").BarPosition;
const Key = @import("enums.zig").Key;
const Button = @import("enums.zig").Button;
const Rule = @import("enums.zig").Rule;
const F = @import("main.zig");

pub const BUTTONMASK = X.ButtonPressMask | X.ButtonReleaseMask;
pub const MOUSEMASK = BUTTONMASK | X.PointerMotionMask;

// AwesomeWM provides a very helpful graphic here:
// https://awesomewm.org/doc/api/libraries/mouse.html

/// Left click.
const Button1 = X.Button1;
/// Middle click.
const Button2 = X.Button2;
/// Right click.
const Button3 = X.Button3;

/// Number of pixels to snap during movement.
pub const snap: i32 = 32;

/// border pixel of windows
pub const borderpx: u32 = 1;

pub const tags = [_][]const u8{ "1", "2", "3", "4", "T" };

// Amazingly, Zig throws a COMPILE ERROR if `tags.len` is >= 32. This is because
// the maximum meaningful left-shift is by 31 for a u32 type, and so Zig
// takes a u5 as the left-shift amount. Which means that `tags.len` will first
// be casted to a u5 and panics with "type 'u5' cannot represent integer ..." if
// it's too large. At which point, either don't use that many tags, or change
// the tag mask to use more bits.
pub const TAGMASK: u32 = (@as(u32, 1) << tags.len) - 1;

pub const fonts = [_][]const u8{"monospace:size=10"};

/// Factor of the master area size [0.05...0.95].
pub const mfact: f32 = 0.5;

/// Number of clients in master area
pub const nmaster = 1;

/// Respect size hints in tiled resizals
pub const resizehints: bool = true;

/// Force focus on the fullscreen window
pub const lockfullscreen: bool = true;

/// Refresh rate (per second) for client move/resize
pub const refreshrate: u16 = 60;

/// False means hide bar.
pub const show_bar: bool = true;

pub const bar_pos: BarPosition = .top;

pub const layouts = [_]lt.Layout{
    .{ .symbol = "[]=", .arrange = F.tile },
    .{ .symbol = "><>", .arrange = null },
    .{ .symbol = "[M]", .arrange = F.monocle },
};

const col_gray1: []const u8 = "#222222";
const col_gray2: []const u8 = "#444444";
const col_gray3: []const u8 = "#bbbbbb";
const col_gray4: []const u8 = "#eeeeee";
const col_accent_400: []const u8 = "#d8b4fe";
const col_accent_900: []const u8 = "#581c87";

fn colors_() EnumArray(SchemeState, Scheme([]const u8)) {
    // As of the time of writing, LSP doesn't quite work here in terms of
    // suggesting the `SchemeState` as the keys. It will still catch nicely at
    // comptime though.
    var c: EnumArray(SchemeState, Scheme([]const u8)) = undefined;
    c.set(.Normal, .{ .fg = col_gray3, .bg = col_gray1, .border = col_gray2 });
    c.set(.Selected, .{ .fg = col_gray1, .bg = col_accent_400, .border = col_accent_900 });
    c.set(.Bar, .{ .fg = col_gray3, .bg = col_gray2, .border = col_gray2 });
    return c;
}
pub const colors = colors_();

const MODKEY = X.Mod4Mask;
pub const keys = [_]Key{
    // TODO: test to see if we DON'T specify null at the end of an args array,
    // will there still be a null there thanks to Zig?
    .{ .mod = MODKEY, .sym = X.XK_space, .func = F.spawn, .arg = .{ .args = &.{"hey"} } },
};

// zig fmt: off
pub const buttons = [_]Button{
.init(.LtSymbol,   0, Button1, F.setLayout     , undefined            ),
.init(.LtSymbol,   0, Button3, F.setLayout     , .{ .l = &layouts[2] }),
.init(.WinTitle,   0, Button2, F.zoom          , undefined            ),
.init(.StatusText, 0, Button2, F.spawn         , .{.args = &.{}}      ),
.Init(.ClientWin,  0, Button1, F.moveMouse     , undefined            ),
.init(.ClientWin,  0, Button2, F.toggleFloating, undefined            ),
// .{ .click = .ClientWin,  .mask = 0, .button = Button1, .func = F.moveMouse, .arg = undefined             },
};
// // zig fmt: on

// static const Button buttons[] = {
//     /* click                event mask      button          function        argument */
//     { ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
//     { ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
//     { ClkWinTitle,          0,              Button2,        zoom,           {0} },
//     { ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
//     { ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
//     { ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
//     { ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
//     { ClkTagBar,            0,              Button1,        view,           {0} },
//     { ClkTagBar,            0,              Button3,        toggleview,     {0} },
//     { ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
//     { ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
// };


pub const rules = [_]Rule{};
