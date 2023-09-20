const std = @import("std");
const builtin = @import("builtin");

const soft = @import("soft");
const backend = @import("root"); // TODO: https://github.com/ziglang/zig/issues/14708: @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

pub fn init() !void {}

pub fn tick(time: anytype) !void {
    _ = time;

    grid.drawRectangle(
        0,
        0,
        @as(isize, @intCast(grid.width)),
        @as(isize, @intCast(grid.height)),
        Color.verticalGradient(Color.red, Color.green),
    );
}
