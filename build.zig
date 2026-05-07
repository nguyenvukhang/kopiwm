const std = @import("std");
const appVersion = @import("build.zig.zon").version;

const c_libraries = [_][]const u8{
    "X11",
    "Xft",
    "fontconfig",
    // "freetype",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "kopiwm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });
    const opts = b.addOptions();
    opts.addOption([]const u8, "version", appVersion);
    opts.addOption([]const u8, "name", exe.name);
    exe.root_module.addOptions("build_opts", opts);

    exe.linkLibC();
    for (c_libraries) |c_library| {
        exe.root_module.linkSystemLibrary(c_library, .{});
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
