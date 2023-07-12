const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const grids = @import("../../grids.zig");
const Color = grids.Color;
const color_helpers = @import("../color_helpers.zig");

pub fn DrawingHelpers(comptime Grid: type, comptime options: grids.Options) type {
    const Cell = options.Cell;

    return struct {
        fn getIndex(grid: Grid, x: isize, y: isize) ?usize {
            if (x < 0 or y < 0)
                return null;

            const index = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * grid.width;

            switch (options.oob_behavior) {
                .clip => {
                    if (x >= grid.width or y >= grid.height)
                        return null;
                },
                .wrap => {
                    if (index >= grid.cells().len)
                        return null;
                },
                .fast => {},
            }

            return index;
        }

        pub fn set(grid: *Grid, x: isize, y: isize, cell: Cell) void {
            if (getIndex(grid.*, x, y)) |index|
                grid.cells()[index] = cell;
        }

        pub fn get(grid: Grid, x: isize, y: isize) switch (options.oob_behavior) {
            .clip, .wrap => ?Cell,
            .fast => Cell,
        } {
            if (getIndex(grid, x, y)) |index|
                return grid.cellsSlice()[index];
            switch (options.oob_behavior) {
                .clip, .wrap => return null,
                .fast => {
                    // we crashed with an error or caused UB depending on the build mode
                },
            }
        }

        pub fn fill(grid: *Grid, cell: Cell) void {
            for (grid.cells()) |*current_cell|
                current_cell.* = cell;
        }

        pub fn content(comptime cell: Cell) Grid.Content {
            return struct {
                fn function(x: f32, y: f32) Cell {
                    _ = x;
                    _ = y;
                    return cell;
                }
            }.function;
        }

        // TODO: /// Draws another grid inside this one.
        // pub fn drawGrid(grid: *Grid, other_grid: anytype, x: isize, y: isize) void {
        //     _ = y;
        //     _ = x;
        //     _ = other_grid;
        //     _ = grid;
        // }

        // TODO: /// Scales the given part of the grid up by the given factor.
        // pub fn scale(grid: *Grid, x: isize, y: isize, width: usize, height: usize, factor: f32) void {
        //     _ = factor;
        //     _ = height;
        //     _ = width;
        //     _ = y;
        //     _ = x;
        //     _ = grid;
        // }
    };
}
