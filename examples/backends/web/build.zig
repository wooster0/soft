const std = @import("std");
const Build = std.Build;
const Module = Build.Module;
const mem = std.mem;

const webserver = @import("webserver.zig");

pub fn build(
    b: *Build.Builder,
    optimize: std.builtin.OptimizeMode,
    wool_module: *Module,
    example_module: *Module,
    other_module: *Module,
) !void {
    // TODO: one of the features causes an unsupported opcode 0x12 to be emitted; report a bug?
    //       wouldn't it be good if we could turn on all features?
    // Enabling bulk memory operations and SIMD can significantly improve performance.
    var features = std.Target.Cpu.Feature.Set.empty;
    features.addFeature(@enumToInt(std.Target.wasm.Feature.bulk_memory));
    features.addFeature(@enumToInt(std.Target.wasm.Feature.simd128));
    const wasm = b.addSharedLibrary(.{
        .name = "web-example",
        .root_source_file = .{ .path = "examples/backends/web/src/main.zig" },
        .optimize = optimize,
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .cpu_features_add = features,
        },
    });
    wasm.addModule("wool", wool_module);
    wasm.addModule("example", example_module);
    wasm.addModule("other", other_module);
    wasm.single_threaded = true;
    wasm.rdynamic = true; // Include exports in binary.
    const dest_path = thisDir();
    b.install_prefix = dest_path; 
    b.install_path = dest_path; 
    wasm.override_dest_dir = .{ .custom = "static" }; // Names I considered for the root dir: static, www, public
    b.installArtifact(wasm);

    // NOTE: in hindsight, I think it's a bad idea to automatically run the webserver like this and the user should be required to run it themselves, especially for development
    var run_webserver_step = try b.allocator.create(std.build.Step);
    const runWebserver = struct {
        fn runWebserver(step: *std.build.Step, progress: *std.Progress.Node) !void {
            _ = step;
            _ = progress;
            try webserver.run("examples/backends/web/static");
        }
    }.runWebserver;
    run_webserver_step.* = std.build.Step.init(.{
        .id = .run,
        .name = "run webserver",
        .owner = b,
        .makeFn = runWebserver,
    });
    run_webserver_step.dependOn(&wasm.step);

    const run_step = b.step("run", "Run example");
    run_step.dependOn(run_webserver_step);
}

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file).?;
}
