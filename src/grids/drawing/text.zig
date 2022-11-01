//! This can be very helpful for debugging, especially in environments where a simple text output facility is not available.

const std = @import("std");
const builtin = @import("builtin");
const ascii = std.ascii;
const assert = std.debug.assert;
const testing = std.testing;

const grids = @import("../../grids.zig");
const BitMap = @import("../bit_map.zig").BitMap;

/// A monospace (as opposed to proportional) bitmap font supporting all ASCII characters,
/// optimized for legibility while staying small in size.
const default_charset = struct {
    // this is the minimal size for decent legibility of all ASCII printables
    const width = 5;
    const height = 5;

    // TODO: might be able to remove the `?` prefices in the types after https://github.com/ziglang/zig/issues/13347
    // TODO: this is where zig lacks in brevity. It should allow writing only `        .init`: https://github.com/ziglang/zig/issues/9938
    const misc1 = [_]?BitMap(.{}, width, height){
        // space
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00000,
            0b00000,
            0b00000,
            0b00000,
        }),
        // exclamation mark
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b00100,
            0b00100,
            0b00000,
            0b00100,
        }),
        // double quote
        BitMap(.{}, width, height).init(.{
            0b01010,
            0b01010,
            0b00000,
            0b00000,
            0b00000,
        }),
        // hash
        BitMap(.{}, width, height).init(.{
            0b01010,
            0b11111,
            0b01010,
            0b11111,
            0b01010,
        }),
        // dollar sign
        BitMap(.{}, width, height).init(.{
            0b01111,
            0b10100,
            0b01110,
            0b00101,
            0b11110,
        }),
        // percent sign
        BitMap(.{}, width, height).init(.{
            0b11001,
            0b11010,
            0b00100,
            0b01011,
            0b10011,
        }),
        // ampersand
        BitMap(.{}, width, height).init(.{
            0b01000,
            0b10100,
            0b01001,
            0b10110,
            0b01100,
        }),
        // apostrophe
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b00100,
            0b00000,
            0b00000,
            0b00000,
        }),
        // left parenthesis
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b01000,
            0b01000,
            0b01000,
            0b00100,
        }),
        // right parenthesis
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b00010,
            0b00010,
            0b00010,
            0b00100,
        }),
        // asterisk
        BitMap(.{}, width, height).init(.{
            0b10010,
            0b01100,
            0b01100,
            0b10010,
            0b00000,
        }),
        // plus sign
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b00100,
            0b11111,
            0b00100,
            0b00100,
        }),
        // comma
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00000,
            0b00000,
            0b00100,
            0b01000,
        }),
        // minus sign
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00000,
            0b11111,
            0b00000,
            0b00000,
        }),
        // period
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00000,
            0b00000,
            0b01100,
            0b01100,
        }),
        // slash
        BitMap(.{}, width, height).init(.{
            0b00001,
            0b00010,
            0b00100,
            0b01000,
            0b10000,
        }),
    };

    /// The Arabic numerals.
    const digits = [10]?BitMap(.{}, width, height){
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10011,
            0b10101,
            0b11001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b01100,
            0b00100,
            0b00100,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b00010,
            0b01100,
            0b11111,
        }),
        BitMap(.{}, width, height).init(.{
            0b11110,
            0b00001,
            0b11111,
            0b00001,
            0b11110,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b10001,
            0b11111,
            0b00001,
            0b00001,
        }),
        BitMap(.{}, width, height).init(.{
            0b11111,
            0b10000,
            0b11110,
            0b00001,
            0b11110,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10000,
            0b11110,
            0b10001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b11111,
            0b00010,
            0b00100,
            0b01000,
            0b10000,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b01110,
            0b10001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b01111,
            0b00001,
            0b01110,
        }),
    };

    const misc2 = [_]?BitMap(.{}, width, height){
        // colon
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00100,
            0b00000,
            0b00100,
            0b00000,
        }),
        // semicolon
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00100,
            0b00000,
            0b00100,
            0b01000,
        }),
        // less-than sign
        BitMap(.{}, width, height).init(.{
            0b00010,
            0b00100,
            0b01000,
            0b00100,
            0b00010,
        }),
        // equals sign
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b11111,
            0b00000,
            0b11111,
            0b00000,
        }),
        // greater-than sign
        BitMap(.{}, width, height).init(.{
            0b01000,
            0b00100,
            0b00010,
            0b00100,
            0b01000,
        }),
        // question mark
        BitMap(.{}, width, height).init(.{
            0b01100,
            0b00010,
            0b00100,
            0b00000,
            0b00100,
        }),
        // at sign
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b10101,
            0b10110,
            0b01111,
        }),
    };

    /// The uppercase Latin alphabet.
    const uppercase_letters = [26]?BitMap(.{}, width, height){
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b01010,
            0b10001,
            0b11111,
            0b10001,
        }),
        BitMap(.{}, width, height).init(.{
            0b11110,
            0b10001,
            0b11110,
            0b10001,
            0b11110,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b10000,
            0b10001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b11110,
            0b10001,
            0b10001,
            0b10001,
            0b11110,
        }),
        BitMap(.{}, width, height).init(.{
            0b11111,
            0b10000,
            0b11111,
            0b10000,
            0b11111,
        }),
        BitMap(.{}, width, height).init(.{
            0b11111,
            0b10000,
            0b11111,
            0b10000,
            0b10000,
        }),
        BitMap(.{}, width, height).init(.{
            0b01111,
            0b10000,
            0b10111,
            0b10001,
            0b01111,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b10001,
            0b11111,
            0b10001,
            0b10001,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b00100,
            0b00100,
            0b00100,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b00010,
            0b00010,
            0b10010,
            0b01100,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b10010,
            0b11100,
            0b10010,
            0b10001,
        }),
        BitMap(.{}, width, height).init(.{
            0b10000,
            0b10000,
            0b10000,
            0b10000,
            0b11110,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b11011,
            0b10101,
            0b10001,
            0b10001,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b11001,
            0b10101,
            0b10011,
            0b10001,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b10001,
            0b10001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b01001,
            0b01110,
            0b01000,
            0b01000,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b10001,
            0b10001,
            0b10010,
            0b01101,
        }),
        BitMap(.{}, width, height).init(.{
            0b01110,
            0b01001,
            0b01110,
            0b01001,
            0b01001,
        }),
        BitMap(.{}, width, height).init(.{
            0b01111,
            0b10000,
            0b01110,
            0b00001,
            0b11110,
        }),
        BitMap(.{}, width, height).init(.{
            0b11111,
            0b00100,
            0b00100,
            0b00100,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b10001,
            0b10001,
            0b10001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b10001,
            0b01010,
            0b01010,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b10101,
            0b10101,
            0b10101,
            0b10101,
            0b01010,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b01010,
            0b00100,
            0b01010,
            0b10001,
        }),
        BitMap(.{}, width, height).init(.{
            0b10001,
            0b01010,
            0b00100,
            0b00100,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b11111,
            0b00010,
            0b00100,
            0b01000,
            0b11111,
        }),
    };

    const misc3 = [_]?BitMap(.{}, width, height){
        // left bracket
        BitMap(.{}, width, height).init(.{
            0b01100,
            0b01000,
            0b01000,
            0b01000,
            0b01100,
        }),
        // backslash
        BitMap(.{}, width, height).init(.{
            0b10000,
            0b01000,
            0b00100,
            0b00010,
            0b00001,
        }),
        // right bracket
        BitMap(.{}, width, height).init(.{
            0b00110,
            0b00010,
            0b00010,
            0b00010,
            0b00110,
        }),
        // caret
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b01010,
            0b00000,
            0b00000,
            0b00000,
        }),
        // underscore
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00000,
            0b00000,
            0b00000,
            0b11111,
        }),
        // backtick
        BitMap(.{}, width, height).init(.{
            0b01000,
            0b00100,
            0b00000,
            0b00000,
            0b00000,
        }),
    };

    const lowercase_letters = [26]?BitMap(.{}, width, height){
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01110,
            0b10001,
            0b10011,
            0b01101,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01000,
            0b01110,
            0b01001,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00110,
            0b01000,
            0b01000,
            0b00110,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00001,
            0b01111,
            0b10001,
            0b01111,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01100,
            0b11110,
            0b10000,
            0b01110,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00110,
            0b00100,
            0b01110,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01110,
            0b01110,
            0b00010,
            0b01100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01000,
            0b01000,
            0b01100,
            0b01010,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00100,
            0b00000,
            0b00100,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00010,
            0b00010,
            0b01010,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01010,
            0b01100,
            0b01010,
            0b01010,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01000,
            0b01000,
            0b01000,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b10000,
            0b11110,
            0b10101,
            0b10101,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00000,
            0b01100,
            0b01010,
            0b01010,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00100,
            0b01010,
            0b01010,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01100,
            0b01010,
            0b01100,
            0b01000,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00110,
            0b01010,
            0b00110,
            0b00010,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01010,
            0b01100,
            0b01000,
            0b01000,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00110,
            0b01100,
            0b00110,
            0b01100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b00100,
            0b01110,
            0b00100,
            0b00110,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01010,
            0b01010,
            0b01010,
            0b00110,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b10001,
            0b10001,
            0b01010,
            0b00100,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b10101,
            0b10101,
            0b10101,
            0b01010,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01010,
            0b00100,
            0b01010,
            0b01010,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b10001,
            0b01010,
            0b00100,
            0b11000,
        }),
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01110,
            0b00010,
            0b00100,
            0b01110,
        }),
    };
    comptime {
        // some letters are distinguished from their uppercase counterparts solely by their size,
        // so for consistency we require all lowercase letters to be of height 4
        for (lowercase_letters) |letter|
            assert(letter.?.bit_sets[0] == 0b00000);
    }

    const misc4 = [_]?BitMap(.{}, width, height){
        // left brace
        BitMap(.{}, width, height).init(.{
            0b00010,
            0b00100,
            0b01100,
            0b00100,
            0b00010,
        }),
        // vertical bar
        BitMap(.{}, width, height).init(.{
            0b00100,
            0b00100,
            0b00100,
            0b00100,
            0b00100,
        }),
        // right brace
        BitMap(.{}, width, height).init(.{
            0b01000,
            0b00100,
            0b00110,
            0b00100,
            0b01000,
        }),
        // tilde
        BitMap(.{}, width, height).init(.{
            0b00000,
            0b01000,
            0b10101,
            0b00010,
            0b00000,
        }),
    };

    // TODO: extended ASCII (256) for Scandinavian languages etc.?
    const ascii_table: [128]?BitMap(.{}, width, height) =
        [1]?BitMap(.{}, width, height){null} ** 32 ++ // controls
        // start of printables
        misc1 ++
        digits ++
        misc2 ++
        uppercase_letters ++
        misc3 ++
        lowercase_letters ++
        misc4 ++
        // end of printables
        [1]?BitMap(.{}, width, height){null}; // another control
};

pub fn Text(comptime Grid: type, comptime grid_options: grids.Options) type {
    const Cell = grid_options.Cell;

    return struct {
        // TODO: this is also in shapes.zig
        fn getCell(content: Grid.Content, x: usize, y: usize, width: usize, height: usize) Cell {
            // normalize so that our callee doesn't have to think about size
            return content(
                @intToFloat(grid_options.Float, x) / @intToFloat(grid_options.Float, width),
                @intToFloat(grid_options.Float, y) / @intToFloat(grid_options.Float, height),
            );
        }

        const Options = struct {
            charset: struct {
                bitmaps: [128]?BitMap(.{}, default_charset.width, default_charset.height) = default_charset.ascii_table,
                width: comptime_int = default_charset.width,
                height: comptime_int = default_charset.height,
            } = .{},
            content: enum { per_letter, per_cell } = .per_letter,
            /// All characters are run through this function before being drawn.
            map: *const fn (char: u8, index: usize) u8 = struct {
                fn map(char: u8, index: usize) u8 {
                    _ = index;
                    return char;
                }
            }.map,
            fallback: BitMap(.{}, default_charset.width, default_charset.height) = default_charset.ascii_table['?'].?,
            gap: usize = 1,
            /// Whether to handle special control characters like newlines that adjust the Y-axis.
            handle_controls: bool = true,
            scale_x: isize = 1,
            scale_y: isize = 1,
        };

        const DrawTextError = error{InvalidChar};

        pub fn drawText(grid: *Grid, comptime options: Options, comptime fmt: []const u8, args: anytype, x: isize, y: isize, content: Grid.Content) DrawTextError!void {
            const Context = struct {
                grid: *Grid,
                x: isize,
                y: isize,
                content: Grid.Content,
                // max_len: usize,
                offset_x: usize = 0,
                offset_y: usize = 0,
            };

            // by using a custom writer we can stream the data and avoid using a buffer
            const writeFn = struct {
                fn writeFn(context: *Context, string: []const u8) DrawTextError!usize {
                    for (string) |unmapped_char| {
                        const char = options.map(unmapped_char, context.offset_x);

                        const bit_map = bit_map: {
                            if (default_charset.ascii_table[char]) |bit_map| {
                                assert(ascii.isPrint(char));
                                break :bit_map bit_map;
                            } else {
                                assert(ascii.isControl(char));
                                break :bit_map switch (char) {
                                    '\n' => {
                                        context.offset_x = 0;
                                        context.offset_y += 1;
                                        continue;
                                    },
                                    else => options.fallback,
                                };
                            }
                        };

                        bit_map.draw(
                            .{ .scale_x = options.scale_x, .scale_y = options.scale_y },
                            context.grid,
                            context.x + @intCast(isize, context.offset_x) * (options.charset.width + options.gap),
                            context.y + @intCast(isize, context.offset_y) * (options.charset.height + options.gap),
                            @as(?Grid.Content, context.content),
                            @as(?Grid.Content, null),
                        );

                        context.offset_x += 1;
                    }

                    return string.len;
                }
            }.writeFn;

            var context = Context{
                .grid = grid,
                .x = x,
                .y = y,
                .content = content,
                // .max_len = std.fmt.count(fmt, args),
            };

            const writer = std.io.Writer(*Context, DrawTextError, writeFn){ .context = &context };
            return std.fmt.format(writer, fmt, args);
        }

        // TODO: pub fn getTextSize(grid: Grid, comptime fmt: []const u8, args: anytype) struct { width: usize, height: usize } {
        //     _ = grid; // TODO: where to put this function?
        //     return .{
        //         .width = std.fmt.count(fmt, args) * (text_options.charset.width + gap),
        //         .height = char_height,
        //     };
        // }
    };
}

// TODO: we need more tests

comptime {
    if (builtin.is_test) {}
}
