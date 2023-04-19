const std = @import("std");
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
        .name = "none-example",
        .root_source_file = .{ .path = "examples/backends/none/src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("wool", wool_module);
    exe.addModule("example", example_module);
    exe.addModule("other", other_module);
    b.installArtifact(exe);
    const run_artifact = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run example");
    run_step.dependOn(&run_artifact.step);
}
