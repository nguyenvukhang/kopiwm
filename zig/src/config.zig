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
const M = @import("main.zig");

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
    .{ .symbol = "[]=", .arrange = M.tile },
    .{ .symbol = "><>", .arrange = null },
    .{ .symbol = "[M]", .arrange = M.monocle },
};

const col_gray1: []const u8 = "#222222";
const col_gray2: []const u8 = "#444444";
const col_gray3: []const u8 = "#bbbbbb";
const col_gray4: []const u8 = "#eeeeee";
const col_accent_400: []const u8 = "#d8b4fe";
const col_accent_900: []const u8 = "#581c87";

fn initColors() EnumArray(SchemeState, Scheme([]const u8)) {
    var c: EnumArray(SchemeState, Scheme([]const u8)) = undefined;
    // zig fmt: off
    c.set(.Normal,   .{ .fg = col_gray3, .bg = col_gray1,      .border = col_gray2      });
    c.set(.Selected, .{ .fg = col_gray1, .bg = col_accent_400, .border = col_accent_900 });
    c.set(.Bar,      .{ .fg = col_gray3, .bg = col_gray2,      .border = col_gray2      });
    // zig fmt: on
    return c;
}

pub const colors = initColors();

const MODKEY = X.Mod4Mask;
pub const keys = [_]Key{
    // TODO: test to see if we DON'T specify null at the end of an args array,
    // will there still be a null there thanks to Zig?
    .init(MODKEY, X.XK_space, .f(M.spawn, .{ .args = &.{"hey"} })),
    // .{ .mod = MODKEY, .sym = X.XK_space, .func = M.spawn, .arg = .{ .args = &.{"hey"} } },
};

// { MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
// { MODKEY|ShiftMask,             XK_Return, spawn,          {.v = termcmd } },
// { MODKEY,                       XK_b,      togglebar,      {0} },
// { MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
// { MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
// { MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
// { MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
// { MODKEY,                       XK_h,      setmfact,       {.f = -0.05} },
// { MODKEY,                       XK_l,      setmfact,       {.f = +0.05} },
// { MODKEY,                       XK_Return, zoom,           {0} },
// { MODKEY,                       XK_Tab,    view,           {0} },
// { MODKEY|ShiftMask,             XK_c,      killclient,     {0} },
// { MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
// { MODKEY,                       XK_f,      setlayout,      {.v = &layouts[1]} },
// { MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} },
// { MODKEY,                       XK_space,  setlayout,      {0} },
// { MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
// { MODKEY,                       XK_0,      view,           {.ui = ~0 } },
// { MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
// { MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
// { MODKEY,                       XK_period, focusmon,       {.i = +1 } },
// { MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
// { MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
// TAGKEYS(                        XK_1,                      0)
// TAGKEYS(                        XK_2,                      1)
// TAGKEYS(                        XK_3,                      2)
// TAGKEYS(                        XK_4,                      3)
// TAGKEYS(                        XK_5,                      4)
// TAGKEYS(                        XK_6,                      5)
// TAGKEYS(                        XK_7,                      6)
// TAGKEYS(                        XK_8,                      7)
// TAGKEYS(                        XK_9,                      8)
// { MODKEY|ShiftMask,             XK_q,      quit,           {0} },

// zig fmt: off
pub const buttons = [_]Button{
.init(.LtSymbol,     0,        Button1,   .f( M.setLayout,        undefined             )),
.init(.LtSymbol,     0,        Button3,   .f( M.setLayout,        .{ .l = &layouts[2] } )),
.init(.WinTitle,     0,        Button2,   .f( M.zoom,             undefined             )),
.init(.StatusText,   0,        Button2,   .f( M.spawn,            .{.args = &.{}}       )),
.init(.ClientWin,    MODKEY,   Button1,   .F( M.moveMouse,        undefined             )),
.init(.ClientWin,    MODKEY,   Button2,   .f( M.toggleFloating,   undefined             )),
.init(.ClientWin,    MODKEY,   Button3,   .F( M.resizeMouse,      undefined             )),
.init(.TagBar,       0,        Button1,   .f( M.view,             undefined             )),
.init(.TagBar,       0,        Button3,   .f( M.toggleView,       undefined             )),
.init(.TagBar,       MODKEY,   Button1,   .f( M.tag,              undefined             )),
.init(.TagBar,       MODKEY,   Button3,   .f( M.toggleTag,        undefined             )),
};
// // zig fmt: on

pub const rules = [_]Rule{};
