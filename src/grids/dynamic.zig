const std = @import("std");
const mem = std.mem;

const grids = @import("../grids.zig");
const other = @import("../other.zig");

/// A dynamically resizable general-purpose grid for storage of cells.
pub fn DynamicGrid(comptime options: grids.Options) type {
    return struct {
        const Grid = @This();

        // for compatibility with StaticCanvas we want the user to use `cells()`
        /// Use `Grid.cells()`.
        cellsPtr: [*]options.Cell, // no need for a fat pointer (slice); the length is tracked using `width` and `height`
        width: usize,
        height: usize,

        pub fn init(allocator: mem.Allocator, width: usize, height: usize) !Grid {
            return Grid{
                .cellsPtr = (try allocator.alloc(options.Cell, width * height)).ptr,
                .width = width,
                .height = height,
            };
        }

        pub fn deinit(grid: *Grid, allocator: mem.Allocator) void {
            allocator.free(grid.cells());
        }

        /// Resizes the grid to the given new size.
        pub fn resize(grid: *Grid, allocator: mem.Allocator, width: usize, height: usize) !void {
            grid.deinit(allocator);
            grid.cellsPtr = (try allocator.alloc(options.Cell, width * height)).ptr;
            grid.width = width;
            grid.height = height;
        }

        /// Returns the grid's cells as one contiguous array.
        ///
        /// Be careful not to accidentally take another pointer to this to avoid pointer indirection.
        pub fn cells(grid: *Grid) []options.Cell {
            return grid.cellsPtr[0..grid.len()];
        }

        /// Returns the grid's cells as a contiguous array.
        /// The difference to `cells` is that this does not require a mutable `Grid`.
        pub fn cellsSlice(grid: Grid) []options.Cell {
            return grid.cellsPtr[0..grid.len()];
        }

        pub fn len(grid: Grid) usize {
            return grid.width * grid.height;
        }

        pub usingnamespace grids.Imports(Grid, options);
    };
}
