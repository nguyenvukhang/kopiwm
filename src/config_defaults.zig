const std = @import("std");
const k = @import("x_tutorial.zig").keys;
const Layout = @import("layout.zig").Layout;
const SchemeState = @import("enums.zig").SchemeState;
const Scheme = @import("drw.zig").Scheme;
const EnumArray = @import("enum_array.zig").EnumArray;
const Key = @import("enums.zig").Key;
const Button = @import("enums.zig").Button;
const M = @import("main.zig");
const cfg = @import("config.zig");

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

const ShiftMask = k.ShiftMask;
const ControlMask = k.ControlMask;

const MODKEY = k.Mod4Mask;
const launchcmd: [*:null]const ?[*:0]const u8 = &.{ "rofi", "-show", "run", "-matching", "fuzzy", "-sort", "-sorting-method", "fzf" };
const termcmd: [*:null]const ?[*:0]const u8 = &.{"xterm"};

// zig fmt: off
pub const base_keys = [_]Key{
    .init(MODKEY,            k.XK_p,      .f(M.spawn,          .{ .args = launchcmd  })),
    .init(MODKEY|ShiftMask,  k.XK_Return, .f(M.spawn,          .{ .args = termcmd    })),
    .init(MODKEY,            k.XK_b,      .f(M.toggleBar,      undefined              )),
    .init(MODKEY,            k.XK_j,      .f(M.focusStack,     .{ .d = .Next         })),
    .init(MODKEY,            k.XK_k,      .f(M.focusStack,     .{ .d = .Prev         })),
    .init(MODKEY,            k.XK_i,      .f(M.incNMaster,     .{ .i =  1            })),
    .init(MODKEY,            k.XK_d,      .f(M.incNMaster,     .{ .i = -1            })),
    .init(MODKEY,            k.XK_h,      .f(M.setMFact,       .{ .f =  0.05         })),
    .init(MODKEY,            k.XK_l,      .f(M.incNMaster,     .{ .f = -0.05         })),
    .init(MODKEY,            k.XK_Return, .f(M.zoom,           undefined              )),
    .init(MODKEY,            k.XK_Tab,    .f(M.view,           undefined              )),
    .init(MODKEY|ShiftMask,  k.XK_c,      .f(M.killClient,     undefined              )),
    .init(MODKEY,            k.XK_t,      .f(M.setLayout,      .{ .l = &layouts[0]   })),
    .init(MODKEY,            k.XK_f,      .f(M.setLayout,      .{ .l = &layouts[1]   })),
    .init(MODKEY,            k.XK_m,      .f(M.setLayout,      .{ .l = &layouts[2]   })),
    .init(MODKEY,            k.XK_space,  .f(M.setLayout,      .{ .l = &.empty       })),
    .init(MODKEY|ShiftMask,  k.XK_space,  .f(M.toggleFloating, undefined              )),
    .init(MODKEY,            k.XK_0,      .f(M.view,           .{ .ui = ~@as(u32, 0) })),
    .init(MODKEY|ShiftMask,  k.XK_0,      .f(M.tag,            .{ .ui = ~@as(u32, 0) })),
    .init(MODKEY,            k.XK_comma,  .f(M.focusMon,       .{ .d = .Prev         })),
    .init(MODKEY,            k.XK_period, .f(M.focusMon,       .{ .d = .Next         })),
    .init(MODKEY|ShiftMask,  k.XK_comma,  .f(M.tagMonitor,     .{ .d = .Prev         })),
    .init(MODKEY|ShiftMask,  k.XK_period, .f(M.tagMonitor,     .{ .d = .Next         })),
    .init(MODKEY|ShiftMask,  k.XK_q,      .f(M.quit,           undefined              )),
};
// zig fmt: on

/// A template of what's to be mapped for each tag available.
// zig fmt: off
pub const tag_keys = [_]Key{
    .init(MODKEY,                       0, .f(M.view,       .{ .ui = 0 })),
    .init(MODKEY|ControlMask,           0, .f(M.toggleView, .{ .ui = 0 })),
    .init(MODKEY|ShiftMask,             0, .f(M.tag,        .{ .ui = 0 })),
    .init(MODKEY|ShiftMask|ControlMask, 0, .f(M.toggleTag,  .{ .ui = 0 })),
};
// zig fmt: on

pub const keys = cfg.initKeys(&base_keys);

// zig fmt: off
pub const buttons = [_]Button{
.init(.LtSymbol,     0,        k.Button1,   .f( M.setLayout,        .{ .l = &.empty     } )),
.init(.LtSymbol,     0,        k.Button3,   .f( M.setLayout,        .{ .l = &layouts[2] } )),
.init(.WinTitle,     0,        k.Button2,   .f( M.zoom,             undefined             )),
.init(.StatusText,   0,        k.Button2,   .f( M.spawn,            .{.args = &.{}}       )),
.init(.ClientWin,    MODKEY,   k.Button1,   .F( M.moveMouse,        undefined             )),
.init(.ClientWin,    MODKEY,   k.Button2,   .f( M.toggleFloating,   undefined             )),
.init(.ClientWin,    MODKEY,   k.Button3,   .F( M.resizeMouse,      undefined             )),
.init(.TagBar,       0,        k.Button1,   .f( M.view,             undefined             )),
.init(.TagBar,       0,        k.Button3,   .f( M.toggleView,       undefined             )),
.init(.TagBar,       MODKEY,   k.Button1,   .f( M.tag,              undefined             )),
.init(.TagBar,       MODKEY,   k.Button3,   .f( M.toggleTag,        undefined             )),
};
// zig fmt: on
