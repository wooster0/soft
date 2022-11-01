const std = @import("std");
const builtin = @import("builtin");

const wool = @import("wool");
const backend = @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

pub fn init() !void {}

/// Make this true to see more colors.
const more_colors = true;

pub fn tick(time: anytype) !void {
    // TODO(general): make iterating through cells, while having x and y too, nicer
    for (grid.cells()) |*cell, index| {
        const x = @intCast(u32, index % grid.width);
        const y = @intCast(u32, index / grid.width);

        if (more_colors)
            cell.* = @bitCast(Color, @truncate(
                u24,
                // try other bitwise operations like `&`, `|`, or `^`
                // |    |
                // |    |
                // v    v
                (x ^ y) | @bitCast(
                    u24,
                    Color.rgb(
                        @fabs(@sin(time.elapsed)),
                        @intToFloat(f32, x * y) / @intToFloat(f32, grid.width * grid.height),
                        @fabs(@cos(time.elapsed)),
                    ),
                ),
            ))
        else
            cell.* = @bitCast(Color, @truncate(
                u24,
                // try other bitwise operations like `&`, `|`, or `^`
                x | y,
            ));
    }
}
