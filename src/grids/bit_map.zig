const std = @import("std");
const math = std.math;

const grids = @import("../grids.zig");
const other = @import("../other.zig");

/// A static grid made of ones and zeroes.
pub fn BitMap(comptime grid_options: grids.Options, comptime width: comptime_int, comptime height: comptime_int) type {
    return struct {
        const Grid = @This();

        bit_sets: [height]std.meta.Int(.unsigned, width),
        comptime width: comptime_int = width,
        comptime height: comptime_int = height,

        pub fn init(comptime bit_sets: [height]std.meta.Int(.unsigned, width)) Grid {
            return .{
                .bit_sets = bit_sets,
            };
        }

        pub const Options = struct {
            scale_x: isize = 1,
            scale_y: isize = 1,
        };

        /// Uses `content_one` to draw 1-bits and `content_zero` to draw 0-bits.
        pub fn draw(grid: Grid, options: Options, other_grid: anytype, x: isize, y: isize, content_one: anytype, content_zero: anytype) void {
            for (grid.bit_sets) |bit_set, rel_y| {
                var offset: std.math.IntFittingRange(0, width) = width;
                while (offset > 0) : (offset -= 1) {
                    const mask = @as(std.meta.Int(.unsigned, width), 0b1) << offset - 1;
                    const bit = @boolToInt(bit_set & mask == mask);

                    const rel_x = @intCast(isize, width - offset);

                    const abs_x = x + rel_x;
                    const abs_y = y + @intCast(isize, rel_y);

                    const maybe_content = switch (bit) {
                        0 => content_zero,
                        1 => content_one,
                    };
                    if (maybe_content) |content|
                        other_grid.drawRectangle(
                            abs_x * options.scale_x,
                            abs_y * options.scale_y,
                            options.scale_x,
                            options.scale_y,
                            content,
                        );
                }
            }
        }

        pub usingnamespace grids.Imports(Grid, grid_options);
    };
}

test {
    const bit_map = BitMap(.{}, 5, 5).init(.{
        0b10001,
        0b01010,
        0b00100,
        0b01010,
        0b10001,
    });
    _ = bit_map;
}
