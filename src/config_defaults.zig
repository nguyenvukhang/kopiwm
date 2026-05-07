const std = @import("std");
const X = @import("c_lib.zig").X;
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

const ShiftMask = X.ShiftMask;

const MODKEY = X.Mod4Mask;
const launchcmd: [*:null]const ?[*:0]const u8 = &.{ "rofi", "-show", "run", "-matching", "fuzzy", "-sort", "-sorting-method", "fzf" };
const termcmd: [*:null]const ?[*:0]const u8 = &.{"xterm"};

// zig fmt: off
pub const base_keys = [_]Key{
    .init(MODKEY,            X.XK_p,      .f(M.spawn,          .{ .args = launchcmd  })),
    .init(MODKEY|ShiftMask,  X.XK_Return, .f(M.spawn,          .{ .args = termcmd    })),
    .init(MODKEY,            X.XK_b,      .f(M.toggleBar,      undefined              )),
    .init(MODKEY,            X.XK_j,      .f(M.focusStack,     .{ .d = .Next         })),
    .init(MODKEY,            X.XK_k,      .f(M.focusStack,     .{ .d = .Prev         })),
    .init(MODKEY,            X.XK_i,      .f(M.incNMaster,     .{ .i =  1            })),
    .init(MODKEY,            X.XK_d,      .f(M.incNMaster,     .{ .i = -1            })),
    .init(MODKEY,            X.XK_h,      .f(M.setMFact,       .{ .f =  0.05         })),
    .init(MODKEY,            X.XK_l,      .f(M.incNMaster,     .{ .f = -0.05         })),
    .init(MODKEY,            X.XK_Return, .f(M.zoom,           undefined              )),
    .init(MODKEY,            X.XK_Tab,    .f(M.view,           undefined              )),
    .init(MODKEY|ShiftMask,  X.XK_c,      .f(M.killClient,     undefined              )),
    .init(MODKEY,            X.XK_t,      .f(M.setLayout,      .{ .l = &layouts[0]   })),
    .init(MODKEY,            X.XK_f,      .f(M.setLayout,      .{ .l = &layouts[1]   })),
    .init(MODKEY,            X.XK_m,      .f(M.setLayout,      .{ .l = &layouts[2]   })),
    .init(MODKEY,            X.XK_space,  .f(M.setLayout,      .{ .l = &.empty       })),
    .init(MODKEY|ShiftMask,  X.XK_space,  .f(M.toggleFloating, undefined              )),
    .init(MODKEY,            X.XK_0,      .f(M.view,           .{ .ui = ~@as(u32, 0) })),
    .init(MODKEY|ShiftMask,  X.XK_0,      .f(M.tag,            .{ .ui = ~@as(u32, 0) })),
    .init(MODKEY,            X.XK_comma,  .f(M.focusMon,       .{ .d = .Prev         })),
    .init(MODKEY,            X.XK_period, .f(M.focusMon,       .{ .d = .Next         })),
    .init(MODKEY|ShiftMask,  X.XK_comma,  .f(M.tagMonitor,     .{ .d = .Prev         })),
    .init(MODKEY|ShiftMask,  X.XK_period, .f(M.tagMonitor,     .{ .d = .Next         })),
    .init(MODKEY|ShiftMask,  X.XK_q,      .f(M.quit,           undefined              )),
};
// zig fmt: on

pub const keys = cfg.initKeys(&base_keys);

// zig fmt: off
pub const buttons = [_]Button{
.init(.LtSymbol,     0,        X.Button1,   .f( M.setLayout,        .{ .l = &.empty     } )),
.init(.LtSymbol,     0,        X.Button3,   .f( M.setLayout,        .{ .l = &layouts[2] } )),
.init(.WinTitle,     0,        X.Button2,   .f( M.zoom,             undefined             )),
.init(.StatusText,   0,        X.Button2,   .f( M.spawn,            .{.args = &.{}}       )),
.init(.ClientWin,    MODKEY,   X.Button1,   .F( M.moveMouse,        undefined             )),
.init(.ClientWin,    MODKEY,   X.Button2,   .f( M.toggleFloating,   undefined             )),
.init(.ClientWin,    MODKEY,   X.Button3,   .F( M.resizeMouse,      undefined             )),
.init(.TagBar,       0,        X.Button1,   .f( M.view,             undefined             )),
.init(.TagBar,       0,        X.Button3,   .f( M.toggleView,       undefined             )),
.init(.TagBar,       MODKEY,   X.Button1,   .f( M.tag,              undefined             )),
.init(.TagBar,       MODKEY,   X.Button3,   .f( M.toggleTag,        undefined             )),
};
// zig fmt: on
