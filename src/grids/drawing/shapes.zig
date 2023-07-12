const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const grids = @import("../../grids.zig");
const ColorHelpers = @import("../color_helpers.zig").ColorHelpers;

// TODO: "shapes" -> "primitives"/"graphics"?

// TODO: support shapes without color cells, using custom cells.
/// Functions signatures use signed positions and unsigned sizes.
pub fn Shapes(comptime Grid: type, comptime options: grids.Options) type {
    const Cell = options.Cell;

    return struct {
        // TODO: this is also in text.zig
        fn getCell(content: Grid.Content, x: isize, y: isize, width: usize, height: usize) Cell {
            // normalize so that our callee doesn't have to think about size
            return content(
                @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(width)),
                @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(height)),
            );
        }

        pub fn drawRectangle(grid: *Grid, x: isize, y: isize, width: isize, height: isize, content: Grid.Content) void {
            // TODO: it should be possible to improve this after https://github.com/ziglang/zig/issues/7257
            //       if it supports ranges like 10..0 where you go from a bigger number to a smaller one
            var row: isize = 0;
            while (row < math.absInt(height) catch 0) : (row += 1) {
                var column: isize = 0;
                while (column < math.absInt(width) catch 0) : (column += 1) {
                    grid.set(
                        x + column * math.sign(width),
                        y + row * math.sign(height),
                        getCell(content, column, row, math.absCast(width) - 1, math.absCast(height) - 1),
                    );
                }
            }
        }

        pub const LineOptions = struct {
            width: usize = 1,
        };

        pub fn drawLine(grid: *Grid, line_options: LineOptions, from_x: isize, from_y: isize, to_x: isize, to_y: isize, content: Grid.Content) void {
            // Bresenham's line algorithm

            _ = line_options; // TODO

            const width = math.absCast(to_x - from_x);
            const height = math.absCast(to_y - from_y);

            const dx = @as(isize, @intCast(width));
            const sx: i2 = if (from_x < to_x) 1 else -1;
            const dy = -@as(isize, @intCast(height));
            const sy: i2 = if (from_y < to_y) 1 else -1;
            var err = dx + dy;

            var x = from_x;
            var y = from_y;
            while (true) {
                grid.set(x, y, getCell(content, x - from_x, y - from_y, width, height));
                if (x == to_x and y == to_y) break;
                if (err * 2 >= dy) {
                    if (x == to_x) break;
                    err += dy;
                    x += sx;
                }
                if (err * 2 <= dx) {
                    if (y == to_y) break;
                    err += dx;
                    y += sy;
                }
            }
        }
    };
}

const tests = struct {
    const Grid = grids.StaticGrid(.{
        .Cell = struct {
            r: u8,
            g: u8,
            b: u8,

            pub usingnamespace ColorHelpers(@This(), .{ .color_interpolation = .hsv });
        },
    }, 10, 10);
    const Cell = Grid.Cell;
    const Color = grids.Color(Cell);
    var test_grid = Grid.init();

    // TODO: https://github.com/ziglang/zig/issues/4335
    const CellMap = []const struct { a: u8, b: Cell };

    fn getCell(cell_map: CellMap, char: u8) Cell {
        for (cell_map) |pair| {
            if (pair.a == char)
                return pair.b;
        } else std.debug.panic("character '{c}' unassociated with any cell; add it to the cell map", .{char});
    }
    fn getChar(cell_map: CellMap, cell: Cell) u8 {
        for (cell_map) |pair| {
            if (pair.b.eql(cell))
                return pair.a;
        } else std.debug.panic("cell '{any}' unassociated with any character; add it to the cell map", .{cell});
    }

    fn printTestCanvas(cell_map: CellMap) void {
        var y: isize = 0;
        while (y < test_grid.width) : (y += 1) {
            std.debug.print("\\\\", .{});
            var x: isize = 0;
            while (x < test_grid.width) : (x += 1) {
                std.debug.print("{c}", .{getChar(cell_map, test_grid.get(x, y).?)});
            }
            std.debug.print("\n", .{});
        }
    }

    fn testCanvas(expected: []const u8, cell_map: CellMap) !void {
        var lines = mem.split(u8, expected, "\n");
        var x: isize = 0;
        var y: isize = 0;
        while (lines.next()) |line| {
            for (line) |char| {
                const cell = getCell(cell_map, char);
                testing.expectEqual(cell, test_grid.get(x, y).?) catch |err| {
                    std.debug.print("mismatch at ({}, {})\n", .{ x, y });
                    std.debug.print("actual grid:\n", .{});
                    printTestCanvas(cell_map);
                    return err;
                };
                x += 1;
            }
            x = 0;
            y += 1;
        }
    }

    // const cellMap: CellMap = &.{
    //     .{ .a = ' ', .b = .empty },
    //     .{ .a = '1', .b = .filled },
    // };
    const cellMap: CellMap = &.{
        .{ .a = ' ', .b = Color.black },
        .{ .a = 'r', .b = Color.red },
        .{ .a = 'g', .b = Color.green },
        .{ .a = 'b', .b = Color.blue },
    };

    test "drawing lines" {
        // test_grid.fill(.empty);
        // test_grid.drawLine(0, 0, 5, 5, Canvas.content(.filled));
        // try testCanvas(
        //     \\1
        //     \\ 1
        //     \\  1
        //     \\   1
        //     \\    1
        //     \\     1
        // , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawLine(.{}, 0, 0, 5, 5, Grid.content(Color.red));
        try testCanvas(
            \\r
            \\ r
            \\  r
            \\   r
            \\    r
            \\     r
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawLine(.{}, 5, 5, 0, 0, Grid.content(Color.green));
        try testCanvas(
            \\g
            \\ g
            \\  g
            \\   g
            \\    g
            \\     g
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawLine(.{}, 5, 0, 0, 5, Grid.content(Color.blue));
        try testCanvas(
            \\     b
            \\    b
            \\   b
            \\  b
            \\ b
            \\b
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawLine(.{}, 2, 2, 4, 4, Grid.content(Color.red));
        try testCanvas(
            \\
            \\
            \\  r
            \\   r
            \\    r
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawLine(.{}, 2, 2, 4, 4, Color.horizontalGradient(Color.red, Color.blue));
        try testCanvas(
            \\
            \\
            \\  r
            \\   g
            \\    b
        , cellMap);
    }

    test "drawing rectangles" {
        test_grid.fill(Color.black);
        test_grid.drawRectangle(0, 0, 5, 5, Grid.content(Color.red));
        try testCanvas(
            \\rrrrr
            \\rrrrr
            \\rrrrr
            \\rrrrr
            \\rrrrr
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawRectangle(0, 0, 3, 3, Color.verticalGradient(Color.red, Color.blue));
        try testCanvas(
            \\rr
            \\gg
            \\bb
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawRectangle(0, 0, 2, 2, Color.verticalGradient(Color.red, Color.blue));
        try testCanvas(
            \\rr
            \\bb
        , cellMap);

        test_grid.fill(Color.black);
        test_grid.drawRectangle(5, 5, -5, -5, Color.solid(Color.red));
        try testCanvas(
            \\
            \\ rrrrr
            \\ rrrrr
            \\ rrrrr
            \\ rrrrr
            \\ rrrrr
        , cellMap);
    }
};

comptime {
    if (builtin.is_test)
        _ = tests;
}
