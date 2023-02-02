const std = @import("std");
const builtin = @import("builtin");

pub fn build(
    b: *std.build.Builder,
    mode: std.builtin.Mode,
    wool_pkg: std.build.Pkg,
    example_pkg: std.build.Pkg,
    other_pkg: std.build.Pkg,
) !void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("vulkan-example", "examples/backends/vulkan/src/main.zig");
    exe.addPackage(wool_pkg);
    exe.addPackage(example_pkg);
    exe.addPackage(other_pkg);
    link(exe);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    try compileShader(b, exe, "src/vertex_shader.vert");
    try compileShader(b, exe, "src/fragment_shader.frag");
    const run_step = b.step("run", "Run example");
    run_step.dependOn(&exe.run().step);
}

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

fn link(exe: *std.build.LibExeObjStep) void {
    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");
}

fn compileShader(b: *std.build.Builder, exe: *std.build.LibExeObjStep, comptime path: []const u8) !void {
    _ = exe;
    // TODO(compiler bug): const x = comptime if (exe.build_mode == .Debug) &[_][]const u8{
    //     "-Os", // optimizes SPIR-V to minimize size
    // } else &[0][]const u8{};

    // TODO: should it be zig-out/lib?
    std.fs.cwd().makePath("zig-out/obj") catch |err|
        if (err != error.PathAlreadyExists)
        return err;

    b.getInstallStep().dependOn(
        &b.addSystemCommand(
            &[_][]const u8{
                "glslangValidator",
                comptime thisDir() ++ "/" ++ path,
                "-o",
                "zig-out/obj/" ++ comptime stem(path) ++ ".spv",
                "-V", // create SPIR-V binary, under Vulkan semantics
                "--quiet",
            }, // TODO(compiler bug):  ++ x,
        ).step,
    );
}

// TODO: https://github.com/ziglang/zig/pull/13276
fn stem(path: []const u8) []const u8 {
    const filename = std.fs.path.basename(path);
    const index = std.mem.lastIndexOfScalar(u8, filename, '.') orelse return filename[0..];
    if (index == 0) return path;
    return filename[0..index];
}
