//! The simplest possible example.

const std = @import("std");

const backend = @import("root"); // TODO: https://github.com/ziglang/zig/issues/14708: @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

pub fn init() !void {}

pub fn tick(time: anytype) !void {
    _ = time;

    // draw a red square at position (5, 5) with a size of 10
    grid.drawRectangle(5, 5, 10, 10, Color.solid(Color.red));
}
