const std = @import("std");
const uefi = std.os.uefi;

const soft = @import("soft");
const example = @import("example");
const other = @import("other");

pub const allocator = std.testing.failing_allocator;

pub const Grid = soft.StaticGrid(.{}, 1, 1);
pub var grid: Grid = undefined;

pub const seed: u64 = 0;

pub fn main() !void {
    try example.init();

    var time = soft.Time{};

    while (true) {
        time.update(0);

        // deliberately no sleep

        try example.tick(time);
    }
}
