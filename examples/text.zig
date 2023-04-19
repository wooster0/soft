const std = @import("std");
const ascii = std.ascii;

const backend = @import("root"); // TODO: https://github.com/ziglang/zig/issues/14708: @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

pub fn init() !void {}

pub fn tick(time: anytype) !void {
    comptime var printables: []const u8 = &[_]u8{};
    comptime var char: u8 = 0;
    inline while (comptime ascii.isASCII(char)) : (char += 1) {
        if (comptime ascii.isPrint(char)) {
            printables = printables ++ [1]u8{char};
            if (char != 32 and char % 32 == 0) {
                printables = printables ++ [1]u8{'\n'};
            }
        }
    }

    const fmt = "Hello, world?\nFPS: {d}\n\n{s}";
    const args = .{ time.getFPS(), printables };

    const x = 0;
    const y = 0;

    const scale = 2;

    // this is applied to all characters in the string
    const map = struct {
        fn map(character: u8, index: usize) u8 {
            _ = index;
            return if (character == '?') '!' else character;
        }
    }.map;

    // draw the shadow first
    grid.drawText(.{ .map = map, .scale_x = scale, .scale_y = scale }, fmt, args, x + 1, y + 1, Color.solid(Color.hsl(0, 0, 0.5))) catch unreachable;
    // now the front
    grid.drawText(.{ .map = map, .scale_x = scale, .scale_y = scale }, fmt, args, x, y, Color.solid(Color.white)) catch unreachable;
}
