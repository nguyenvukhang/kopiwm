const Arg = @import("enums.zig").Arg;
const Key = @import("enums.zig").Key;
const App = @import("app.zig").App;
const X = @import("c_lib.zig").X;
const C = @import("c_lib.zig").C;

pub fn spawn(z: *App, arg: *const Arg) void {
    // var sa: C.struct_sigaction = undefined;

    _ = z;
    _ = arg;
}

// void spawn(const Arg *arg) {
//     struct sigaction sa;
//
//     if (arg->v == dmenucmd) {
//         dmenumon[0] = '0' + selmon->num;
//     }
//     if (fork() == 0) {
//         if (dpy) {
//             close(ConnectionNumber(dpy));
//         }
//         setsid();
//
//         sigemptyset(&sa.sa_mask);
//         sa.sa_flags = 0;
//         sa.sa_handler = SIG_DFL;
//         sigaction(SIGCHLD, &sa, NULL);
//
//         execvp(((char **)arg->v)[0], (char **)arg->v);
//         die("dwm: execvp '%s' failed:", ((char **)arg->v)[0]);
//     }
// }
