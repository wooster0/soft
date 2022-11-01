//! This lets you run examples and tests.

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

const wool_pkg = std.build.Pkg{
    .name = "wool",
    .source = .{ .path = "src/main.zig" },
};

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();
    prepTests(b, mode);
    try prepExamples(b, mode);
    // TODO: add a step named "example-test" or similar that compiles (but doesn't run)
    //       all examples with all example backends to check for regressions,
    //       or even better: don't produce binaries but only do the semantic analysis.
    //       in that case it can be done as part of "zig build test" rather than a separate command
}

fn prepTests(b: *std.build.Builder, mode: std.builtin.Mode) void {
    const tests = b.addTest(wool_pkg.source.path);
    tests.setBuildMode(mode);
    const test_step = b.step("test", "Run all tests");
    tests.addPackage(wool_pkg);
    test_step.dependOn(&tests.step);
}

const ExampleBackend = enum { none, opengl, terminal, uefi, vulkan, web };

const example_backend_names = example_backend_names: {
    comptime var names: []const []const u8 = &[_][]const u8{};
    inline for (std.meta.fields(ExampleBackend)) |field| {
        const name = field.name;
        names = names ++ &[_][]const u8{name};
    }
    break :example_backend_names names;
};

fn prepExamples(b: *std.build.Builder, mode: std.builtin.Mode) !void {
    // there are two ways to get arguments:
    // * b.option
    // * b.args
    // we use the first option here
    const maybe_example_name = b.option([]const u8, "example", "The example to run (pass \"help\" for a list)");
    const example_backend = b.option(
        []const u8,
        "backend",
        try fmt.allocPrint(b.allocator,
            \\The backend to use for examples and tests:
            \\                               {s} (default: terminal)
        , .{try mem.join(b.allocator, ", ", example_backend_names)}),
    );
    if (maybe_example_name) |example_name|
        // TODO: maybe come up with a better default example backend
        //       that is native, based on the target?
        //       something like this:
        //       Windows -> DirectX
        //       Linux -> Vulkan
        //       other cases -> OpenGL
        return buildExample(b, mode, example_name, example_backend orelse "terminal")
    else if (example_backend != null)
        std.debug.print("specify an example with -Dexample\n", .{})
    else
        b.getInstallStep().dependOn(&b.addLog(
            \\use `-Dexample` and `-Dbackend` to specify example and backend, respectively.
            \\for example:
            \\`zig build -Dexample=rectangle -Dbackend=terminal`
            \\
        , .{}).step);
}

const list_item_prefix = "∙ ";

fn buildExample(b: *std.build.Builder, mode: std.builtin.Mode, example_name: []const u8, example_backend_name: []const u8) !void {
    const example_dir = try std.fs.cwd().openDir("examples", .{});
    // there are two kinds of examples:
    // one has a directory with a main.zig and the other is a standalone file
    const example_pkg_path = try example_pkg_path: {
        // is it the former?
        example_dir.access(example_name, .{}) catch {
            // or is it the latter?
            example_dir.access(try fmt.allocPrint(b.allocator, "{s}.zig", .{example_name}), .{}) catch try listExamples(example_name);
            break :example_pkg_path fmt.allocPrint(b.allocator, "examples/{s}.zig", .{example_name});
        };
        break :example_pkg_path fmt.allocPrint(b.allocator, "examples/{s}/main.zig", .{example_name});
    };

    // this is the backbone that makes the example run
    const backend_pkg = std.build.Pkg{
        .name = "backend",
        .source = .{ .path = try fmt.allocPrint(b.allocator, "examples/backends/{s}/src/main.zig", .{example_backend_name}) },
    };

    // this is the backend-agnostic example that makes use of the backend behind the scenes
    const example_pkg = std.build.Pkg{
        .name = "example",
        .source = .{ .path = example_pkg_path },
        .dependencies = &.{ wool_pkg, backend_pkg },
    };

    // this is common code shared across backends only to be used by backends
    const other_pkg = std.build.Pkg{
        .name = "other",
        .source = .{ .path = "examples/backends/other.zig" },
    };

    // TODO: could these args ever be useful? for example configuration or something? as argv?
    //if (b.args) |args|
    //    exe.run().addArgs(args);

    if (std.meta.stringToEnum(ExampleBackend, example_backend_name)) |example_backend| {
        try switch (example_backend) {
            .none => @import("examples/backends/none/build.zig")
                .build(b, mode, wool_pkg, example_pkg, other_pkg),
            .opengl => @import("examples/backends/opengl/build.zig")
                .build(b, mode, wool_pkg, example_pkg, other_pkg),
            .terminal => @import("examples/backends/terminal/build.zig")
                .build(b, mode, wool_pkg, example_pkg, other_pkg),
            .uefi => @import("examples/backends/uefi/build.zig")
                .build(b, mode, wool_pkg, example_pkg, other_pkg),
            .vulkan => @panic("todo"), //@import("examples/backends/vulkan/build.zig")
            //.build(b, mode, wool_pkg, example_pkg, other_pkg),
            .web => @import("examples/backends/web/build.zig")
                .build(b, mode, wool_pkg, example_pkg, other_pkg),
        };
    } else {
        std.debug.print(
            \\example backend "{s}" does not exist
            \\available backends:
            \\{s}{s}
            \\
        ,
            .{
                example_backend_name,
                list_item_prefix,
                try mem.join(b.allocator, "\n" ++ list_item_prefix, example_backend_names),
            },
        );
        std.process.exit(1);
    }
}

fn listExamples(non_existent_example_name: []const u8) !void {
    const iterable_example_dir = try std.fs.cwd().openIterableDir("examples", .{});
    std.debug.print(
        \\example "{s}" does not exist
        \\available examples:
        \\
    ,
        .{non_existent_example_name},
    );
    var dir_entries = iterable_example_dir.iterate();
    while (try dir_entries.next()) |dir_entry| {
        switch (dir_entry.kind) {
            .Directory => {
                if (mem.eql(u8, dir_entry.name, "backends"))
                    // this is an implementation detail
                    continue;
                std.debug.print("{s}{s}\n", .{ list_item_prefix, dir_entry.name });
            },
            .File => {
                if (mem.eql(u8, dir_entry.name, "README.md"))
                    // this is documentation
                    continue;
                var parts = mem.split(u8, dir_entry.name, ".");
                std.debug.print("{s}{s}\n", .{ list_item_prefix, parts.first() });
            },
            else => std.debug.print("found something weird: {s}\n", .{dir_entry.name}),
        }
    }
    std.process.exit(1);
}
