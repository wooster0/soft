const std = @import("std");

pub fn build(
    b: *std.build.Builder,
    mode: std.builtin.Mode,
    wool_pkg: std.build.Pkg,
    example_pkg: std.build.Pkg,
    other_pkg: std.build.Pkg,
) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("none-example", "examples/backends/none/src/main.zig");
    exe.addPackage(wool_pkg);
    exe.addPackage(example_pkg);
    exe.addPackage(other_pkg);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    const run_step = b.step("run", "Run example");
    run_step.dependOn(&exe.run().step);
}
