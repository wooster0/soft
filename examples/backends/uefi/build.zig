const std = @import("std");

pub fn build(
    b: *std.build.Builder,
    mode: std.builtin.Mode,
    wool_pkg: std.build.Pkg,
    example_pkg: std.build.Pkg,
    other_pkg: std.build.Pkg,
) !void {
    const efi = b.addExecutable("bootx64", "examples/backends/uefi/src/main.zig");
    efi.addPackage(wool_pkg);
    efi.addPackage(example_pkg);
    efi.addPackage(other_pkg);
    efi.setBuildMode(mode);
    efi.setTarget(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
    });
    efi.setOutputDir("zig-out");
    efi.install();

    // NB: TODO: when you see "lld-link: warning: /align specified without /driver; image may not run",
    //           ignore it; it'll be resolved: https://github.com/ziglang/zig/issues/7484

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
