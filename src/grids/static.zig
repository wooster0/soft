const std = @import("std");

const other = @import("../other.zig");

const grids = @import("../grids.zig");

/// A non-resizable general-purpose grid for storage of cells.
pub fn StaticGrid(comptime options: grids.Options, comptime width: comptime_int, comptime height: comptime_int) type {
    const Cell = options.Cell;

    return struct {
        // TODO: maybe later remove the distinction between grid and canvas
        const Grid = @This();

        // for compatibility with DynamicCanvas we want the user to use `cells()`
        /// Use `Grid.cells()`.
        cellsArr: [width * height]Cell,
        comptime width: comptime_int = width,
        comptime height: comptime_int = height,

        pub fn init() Grid {
            return .{ .cellsArr = undefined };
        }

        /// Returns a pointer to the grid's cells as a contiguous array.
        ///
        /// Be careful not to accidentally take another pointer to this to avoid pointer indirection.
        pub fn cells(grid: *Grid) *[width * height]Cell {
            return &grid.cellsArr;
        }

        /// Returns the grid's cells as a contiguous array.
        /// The difference to `cells` is that this does not require a mutable `Grid`.
        pub fn cellsSlice(grid: Grid) [width * height]Cell {
            return grid.cellsArr;
        }

        pub fn len(grid: Grid) comptime_int {
            return grid.width * grid.height;
        }

        pub usingnamespace grids.Imports(Grid, options);
    };
}
