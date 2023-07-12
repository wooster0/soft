const std = @import("std");
const builtin = @import("builtin");

const wool = @import("wool");
const backend = @import("root"); // TODO: https://github.com/ziglang/zig/issues/14708: @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

pub fn init() !void {}

/// Make this true to see more colors.
const more_colors = true;

pub fn tick(time: anytype) !void {
    // TODO(general): make iterating through cells, while having x and y too, nicer
    for (grid.cells(), 0..) |*cell, index| {
        const x = @as(u32, @intCast(index % grid.width));
        const y = @as(u32, @intCast(index / grid.width));

        if (more_colors)
            cell.* = @as(Color, @bitCast(@as(
                u24,
                // try other bitwise operations like `&`, `|`, or `^`
                //           |    |
                //           |    |
                //           v    v
                @truncate((x ^ y) | @as(
                    u24,
                    @bitCast(Color.rgb(
                        @fabs(@sin(time.elapsed)),
                        @as(f32, @floatFromInt(x * y)) / @as(f32, @floatFromInt(grid.width * grid.height)),
                        @fabs(@cos(time.elapsed)),
                    )),
                )),
            )))
        else
            cell.* = @as(Color, @bitCast(@as(
                u24,
                // try other bitwise operations like `&`, `|`, or `^`
                @truncate(x | y),
            )));
    }
}
