const std = @import("std");
const Build = std.Build;
const Module = Build.Module;

pub fn build(
    b: *Build.Builder,
    optimize: std.builtin.OptimizeMode,
    soft_module: *Module,
    example_module: *Module,
    other_module: *Module,
) void {
    const exe = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = .{ .path = "examples/backends/uefi/src/main.zig" },
        .optimize = optimize,
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .uefi,
            .abi = .msvc,
        },
    });
    exe.addModule("soft", soft_module);
    exe.addModule("example", example_module);
    exe.addModule("other", other_module);
    //efi.setOutputDir("zig-out");
    //exe.override_dest_dir = .{ .custom = "." };
    b.installArtifact(exe);

    const image_path = "zig-out/uefi-example.img";
    // TODO: rewrite this using (the probably more widely available) `qemu-img`?
    //       or just in Zig?
    // TODO: check all system commands for availability and print readable message on error.
    //       sub-TODO: add such a `checkSystemCommand` function to std.build?
    const cmds = [_]*std.build.RunStep{
        b.addSystemCommand(&[_][]const u8{
            "dd", "status=none", "if=/dev/zero", "of=" ++ image_path, "bs=1KiB",
            "count=33KiB", // a little over 32 KiB for FAT32
        }),
        b.addSystemCommand(&[_][]const u8{
            "mformat", "-i", image_path,
            "-F", // use FAT32
        }),
        // add the directories
        b.addSystemCommand(&[_][]const u8{
            "mmd",
            "-i",
            image_path,
            "::/EFI",
        }),
        b.addSystemCommand(&[_][]const u8{
            "mmd",
            "-i",
            image_path,
            "::/EFI/BOOT",
        }),
        // add the .EFI
        b.addSystemCommand(&[_][]const u8{
            "mcopy",
            "-i",
            image_path,
            "zig-out/bootx64.efi",
            "::/EFI/BOOT",
        }),
    };
    for (cmds) |cmd|
        b.getInstallStep().dependOn(&cmd.step);

    const run_in_qemu = b.addSystemCommand(&[_][]const u8{
        "qemu-system-x86_64",
        "-nodefaults",
        "-vga",
        "std",
        "-enable-kvm",
        "-drive",
        "file=" ++ image_path ++ ",media=disk,format=raw",
        "-drive",
        "if=pflash,format=raw,unit=0,file=/usr/share/OVMF/OVMF_CODE.fd,readonly=on",
    });
    const run_step = b.step("run", "Run example");
    run_step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_in_qemu.step);
}
