const std = @import("std");

const soft = @import("soft");
const example = @import("example");
const other = @import("other");

export const width: usize = 512;
export const height: usize = 512;

pub const Grid = soft.StaticGrid(
    .{
        // This format is compatible with Canvas2D and WebGL.
        .Cell = packed struct {
            r: u8,
            g: u8,
            b: u8,
            a: u8 = 255,

            pub usingnamespace soft.ColorHelpers(@This(), .{});
        },
    },
    width,
    height,
);
const Color = Grid.Cell;
pub var grid = Grid.init();

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
pub const allocator = gpa.allocator();

pub var seed: u64 = undefined;

export var grid_ptr = grid.cells();

var time = soft.Time{};

// straight from JS
extern fn @"Math.random"() f64;

export fn init() void {
    seed = @as(u64, @bitCast(@"Math.random"()));
    example.init() catch unreachable;
}

export fn tick(now_ms: f64) void {
    time.update(now_ms);

    // no sleep needed: we run this example using requestAnimationFrame (see main.js)
    // which will run our example at a reasonable speed like 60 FPS or probably the monitor's refresh rate

    const maybe_clear_color = if (@hasDecl(example, "clear_color")) example.clear_color else Color.black;
    if (@as(?Color, maybe_clear_color)) |clear_color|
        grid.fill(clear_color);

    example.tick(time) catch unreachable;
}

// NB: all numbers in JavaScript are always 64-bit floating-point numbers

export fn onmousemove(x: f64, y: f64) void {
    if (@hasDecl(example, "handlePointerMovement"))
        example.handlePointerMovement(@as(isize, @intFromFloat(x)), @as(isize, @intFromFloat(y)));
}

export fn onmousedown(x: f64, y: f64) void {
    if (@hasDecl(example, "handlePointerPressed"))
        example.handlePointerPressed(@as(isize, @intFromFloat(x)), @as(isize, @intFromFloat(y)));
}
export fn onmouseup(x: f64, y: f64) void {
    if (@hasDecl(example, "handlePointerReleased"))
        example.handlePointerReleased(@as(isize, @intFromFloat(x)), @as(isize, @intFromFloat(y)));
}
