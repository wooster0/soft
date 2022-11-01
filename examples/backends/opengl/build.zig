const std = @import("std");
const builtin = @import("builtin");

pub fn build(
    b: *std.build.Builder,
    mode: std.builtin.Mode,
    wool_pkg: std.build.Pkg,
    example_pkg: std.build.Pkg,
    other_pkg: std.build.Pkg,
) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("opengl-example", "examples/backends/opengl/src/main.zig");
    exe.addPackage(wool_pkg);
    exe.addPackage(example_pkg);
    exe.addPackage(other_pkg);
    exe.addPackagePath("wool", "lib/src/main.zig");
    link(exe);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    const run_step = b.step("run", "Run example");
    run_step.dependOn(&exe.run().step);
}

fn link(exe: *std.build.LibExeObjStep) void {
    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    // TODO: do we ever need to link "opengl"?
    if (builtin.os.tag == .windows)
        // TODO: test this on Windows
        exe.linkSystemLibrary("opengl32")
    else
        exe.linkSystemLibrary("GL");
}
