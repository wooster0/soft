const std = @import("std");
const builtin = @import("builtin");

const wool = @import("wool");
const backend = @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

pub fn init() !void {}

pub fn tick(time: anytype) !void {
    _ = time;

    grid.drawRectangle(
        0,
        0,
        @intCast(isize, grid.width),
        @intCast(isize, grid.height),
        Color.verticalGradient(Color.red, Color.green),
    );
}
