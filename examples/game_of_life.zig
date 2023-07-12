//! Conway's Game of Life: <https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life>.

const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");

const wool = @import("wool");
const backend = @import("root"); // TODO: https://github.com/ziglang/zig/issues/14708: @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

const Life = wool.DynamicGrid(.{ .Cell = enum { live, dead } });

var life: Life = undefined;

/// Make this true to add some color to live cells.
const colorful = false;

pub fn init() !void {
    life = try Life.init(backend.allocator, grid.width, grid.height);
    life.fill(.dead);

    // you may uncomment this randomization
    var prng = std.rand.DefaultPrng.init(backend.seed);
    const random = prng.random();
    for (life.cells()) |*cell|
        cell.* = @as(Life.Cell, @enumFromInt(@intFromBool(random.boolean())));

    // block (still life)
    life.set(1, 1, .live);
    life.set(2, 1, .live);
    life.set(1, 2, .live);
    life.set(2, 2, .live);

    // blinker (oscillator)
    life.set(5, 5, .live);
    life.set(6, 5, .live);
    life.set(7, 5, .live);
}

// we fill the grid ourselves
pub const clear_color = null;

pub fn tick(time: anytype) !void {
    try update(backend.allocator);

    if (colorful) {
        for (life.cells(), 0..) |*cell, index| {
            switch (cell.*) {
                .live => {
                    const normal = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(grid.width * grid.height));
                    const color = Color.rgb(
                        @fabs(@sin(time.elapsed)),
                        @fabs(@cos(normal)),
                        normal,
                    );
                    grid.cells()[index] = color;
                },
                .dead => {
                    grid.cells()[index] = Color.black;
                },
            }
        }
    } else {
        for (life.cells(), 0..) |*cell, index|
            grid.cells()[index] = switch (cell.*) {
                .live => Color.white,
                .dead => Color.black,
            };
    }
}

fn update(allocator: mem.Allocator) !void {
    // TODO: do this more efficiently?
    var new_life = try Life.init(allocator, grid.width, grid.height);
    defer new_life.deinit(allocator);

    for (life.cells(), 0..) |cell, index| {
        const x = @as(isize, @intCast(index % grid.width));
        const y = @as(isize, @intCast(index / grid.width));
        const live_neighbor_count = countLiveNeighbors(x, y);

        switch (cell) {
            .live => {
                // any live cell with two or three live neighbors survives
                const survives = live_neighbor_count == 2 or live_neighbor_count == 3;
                new_life.cells()[index] =
                    if (survives) .live else .dead;
            },
            .dead => {
                // any dead cell with three live neighbors becomes a live cell
                const become_live = live_neighbor_count == 3;
                new_life.cells()[index] =
                    if (become_live) .live else .dead;
            },
        }
    }

    for (life.cells(), 0..) |*cell, index|
        cell.* = new_life.cells()[index];
}

fn getNeighbors(x: isize, y: isize) [8]Life.Cell {
    const nw = life.get(x - 1, y - 1) orelse .dead;
    const n = life.get(x, y - 1) orelse .dead;
    const ne = life.get(x + 1, y - 1) orelse .dead;

    const w = life.get(x - 1, y) orelse .dead;
    const e = life.get(x + 1, y) orelse .dead;

    const sw = life.get(x - 1, y + 1) orelse .dead;
    const s = life.get(x, y + 1) orelse .dead;
    const se = life.get(x + 1, y + 1) orelse .dead;

    return [_]Life.Cell{ nw, n, ne, w, e, sw, s, se };
}

fn countLiveNeighbors(x: isize, y: isize) usize {
    const neighbors = getNeighbors(x, y);
    var live_neighbor_count: usize = 0;
    for (neighbors) |neighbor| {
        if (neighbor == .live)
            live_neighbor_count += 1;
    }
    return live_neighbor_count;
}
