const std = @import("std");
const X = @import("c_lib.zig").X;
const lt = @import("layout.zig");
const Layout = @import("layout.zig").Layout;
const SchemeState = @import("enums.zig").SchemeState;
const N = @import("enums.zig").N;
const Scheme = @import("drw.zig").Scheme;
const EnumArray = @import("enum_array.zig").EnumArray;
const Arg = @import("lazy_fn.zig").Arg;
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

const Tag = struct {
    text: []const u8,
    key: X.KeySym,

    fn init(name: []const u8, key: X.KeySym) @This() {
        return .{ .text = name, .key = key };
    }
};

/// The tags. These will determine which clients are visible on the screen.
/// The mask corresponding to the first element of this array would be the one
/// with only the least significant bit set.
/// ```
/// 0b00001 <=> tags[0]
/// 0b00010 <=> tags[1]
/// 0b00100 <=> tags[2]
/// ```
pub const tags = [_]Tag{
    .init("1", X.XK_1),
    .init("2", X.XK_2),
    .init("3", X.XK_3),
    .init("4", X.XK_4),
    .init("T", X.XK_0),
};

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

pub const layouts = [_]Layout{
    .{ .symbol = "[]=", .arrange = M.tile },
    .empty,
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

const AltMask = X.Mod1Mask;
const ControlMask = X.ControlMask;
const ShiftMask = X.ShiftMask;
const HyperMask = AltMask | ControlMask | ShiftMask | X.Mod4Mask;

const MODKEY = X.Mod4Mask;
const termcmd: [*:null]const ?[*:0]const u8 = &.{ "rofi", "-show", "run", "-matching", "fuzzy", "-sort", "-sorting-method", "fzf" };
const launchcmd: [*:null]const ?[*:0]const u8 = &.{"kitty"};

// zig fmt: off
const base_keys = [_]Key{
    // TODO: test to see if we DON'T specify null at the end of an args array,
    // will there still be a null there thanks to Zig?
    .init(MODKEY,             X.XK_p,      .f(M.spawn,          .{ .args = launchcmd  })),
    .init(MODKEY | ShiftMask, X.XK_Return, .f(M.spawn,          .{ .args = termcmd    })),
    .init(MODKEY,             X.XK_b,      .f(M.toggleBar,      undefined              )),
    .init(MODKEY,             X.XK_j,      .f(M.focusStack,     .{ .d = .Next         })),
    .init(MODKEY,             X.XK_k,      .f(M.focusStack,     .{ .d = .Prev         })),
    .init(MODKEY,             X.XK_i,      .f(M.incNMaster,     .{ .i =  1            })),
    .init(MODKEY,             X.XK_d,      .f(M.incNMaster,     .{ .i = -1            })),
    .init(MODKEY,             X.XK_h,      .f(M.setMFact,       .{ .f =  0.05         })),
    .init(MODKEY,             X.XK_l,      .f(M.incNMaster,     .{ .f = -0.05         })),
    .init(MODKEY,             X.XK_Return, .f(M.zoom,           undefined              )),
    .init(MODKEY,             X.XK_Tab,    .f(M.view,           undefined              )),
    .init(MODKEY|ShiftMask,   X.XK_c,      .f(M.killClient,     undefined              )),
    .init(MODKEY,             X.XK_t,      .f(M.setLayout,      .{ .l = &layouts[0]   })),
    .init(MODKEY,             X.XK_f,      .f(M.setLayout,      .{ .l = &layouts[1]   })),
    .init(MODKEY,             X.XK_m,      .f(M.setLayout,      .{ .l = &layouts[2]   })),
    .init(MODKEY,             X.XK_space,  .f(M.setLayout,      undefined              )),
    .init(MODKEY|ShiftMask,   X.XK_space,  .f(M.toggleFloating, undefined              )),
    .init(MODKEY,             X.XK_0,      .f(M.view,           .{ .ui = ~@as(u32, 0) })),
    .init(MODKEY|ShiftMask,   X.XK_0,      .f(M.tag,            .{ .ui = ~@as(u32, 0) })),
    .init(MODKEY,             X.XK_comma,  .f(M.focusMon,       .{ .d = .Prev         })),
    .init(MODKEY,             X.XK_period, .f(M.focusMon,       .{ .d = .Next         })),
    .init(MODKEY|ShiftMask,   X.XK_comma,  .f(M.tagMonitor,     .{ .d = .Prev         })),
    .init(MODKEY|ShiftMask,   X.XK_period, .f(M.tagMonitor,     .{ .d = .Next         })),
    .init(MODKEY|ShiftMask,   X.XK_q,      .f(M.quit,           undefined              )),
};
// zig fmt: on

const K: usize = base_keys.len + 4 * tags.len;
fn initKeys() [K]Key {
    var arr: [K]Key = undefined;
    for (0..base_keys.len) |i| arr[i] = base_keys[i];
    for (0..tags.len) |i| {
        const key = tags[i].key;
        const j = base_keys.len + i * 4;
        const arg: Arg = .{ .ui = @as(u32, 1) << @intCast(i) }; // tag's bitmask
        // zig fmt: off
        arr[j + 0] = .init(MODKEY,                       key, .f(M.view,       arg));
        arr[j + 1] = .init(MODKEY|ControlMask,           key, .f(M.toggleView, arg));
        arr[j + 2] = .init(MODKEY|ShiftMask,             key, .f(M.tag,        arg));
        arr[j + 3] = .init(MODKEY|ShiftMask|ControlMask, key, .f(M.toggleTag,  arg));
        // zig fmt: on
    }
    return arr;
}
pub const keys = initKeys();

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
.init(.LtSymbol,     0,        Button1,   .f( M.setLayout,        .{ .l = &.empty     } )),
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
