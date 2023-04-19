const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const Module = Build.Module;

pub fn build(
    b: *Build.Builder,
    optimize: std.builtin.OptimizeMode,
    wool_module: *Module,
    example_module: *Module,
    other_module: *Module,
) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "vulkan-example",
        .root_source_file = .{ .path = "examples/backends/vulkan/src/main.zig" },
        .optimize = optimize,
        .target = target,
    });
    exe.addModule("wool", wool_module);
    exe.addModule("example", example_module);
    exe.addModule("other", other_module);
    b.installArtifact(exe);
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
