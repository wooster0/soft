const std = @import("std");
const mem = std.mem;

const webserver = @import("webserver.zig");

pub fn build(
    b: *std.build.Builder,
    mode: std.builtin.Mode,
    wool_pkg: std.build.Pkg,
    example_pkg: std.build.Pkg,
    other_pkg: std.build.Pkg,
) !void {
    const wasm = b.addSharedLibrary("web-example", "examples/backends/web/src/main.zig", .unversioned);
    wasm.addPackage(wool_pkg);
    wasm.addPackage(example_pkg);
    wasm.addPackage(other_pkg);
    wasm.setBuildMode(mode);
    // TODO: one of the features cause an unsupported opcode 0x12 to be emitted; report a bug?
    //       wouldn't it be good if we could turn on all features?
    // enabling bulk memory operations and SIMD can significantly improve performance
    var features = std.Target.Cpu.Feature.Set.empty;
    features.addFeature(@enumToInt(std.Target.wasm.Feature.bulk_memory));
    features.addFeature(@enumToInt(std.Target.wasm.Feature.simd128));
    wasm.setTarget(.{
        .os_tag = .freestanding,
        .cpu_arch = .wasm32,
        .cpu_features_add = features,
    });
    wasm.single_threaded = true;
    // TODO: we can't have the Wasm binary be in zig-out because we need to pass the same path
    //       of the directory that index.html etc. are in to the webserver below in runWebserver,
    //       and the index.html etc. should stay in this src/.
    //       can we special-case the Wasm binary's path below in order to put it in the root dir's zig-out?
    //       after that, remove the .gitignore in this src/
    wasm.output_dir = thisDir();
    wasm.install();

    var run_webserver_step = try b.allocator.create(std.build.Step);
    const runWebserver = struct {
        fn runWebserver(step: *std.build.Step) !void {
            _ = step;
            try webserver.run(thisDir());
        }
    }.runWebserver;
    run_webserver_step.* = std.build.Step.init(.run, "run webserver", b.allocator, runWebserver);
    run_webserver_step.dependOn(&wasm.step);

    const run_step = b.step("run", "Run example");
    run_step.dependOn(run_webserver_step);
}

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}
