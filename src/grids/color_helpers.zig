//! # Color helpers
//!
//! Helpers for things like converting between color models.
//!
//! For our purposes, this is when to use which color model:
//! * RGB: primarily for internal color storage.
//! * HSL: for notating colors that a human thought of.
//! * HSV: for color interpolation and such.

// TODO: maybe eventually this can become color.zig or Color.zig

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;

const grids = @import("../grids.zig");
const other = @import("../other.zig");
const lerp = other.lerp;

const Options = struct {
    /// Whether to round or not.
    /// This makes things such as color conversion results more accurate at the cost of performance.
    round: bool = true,
    /// This configures what color model to use internally for color interpolation.
    /// This affects gradients and such.
    ///
    /// For example, if you have a gradient from red to green,
    /// with RGB you will see brown inbetween; with HSV you will see yellow inbetween.
    ///
    /// The options are ordered by performance, from faster to slower.
    // TODO: would be nice if this was runtime-adjustable?
    color_interpolation: enum {
        rgb,
        hsv,
    } = .hsv,
};

pub fn ColorHelpers(comptime Cell: type, comptime options: Options) type {
    const Color = grids.Color(Cell);
    return struct {
        pub fn format(color: Color, comptime fmt: []const u8, format_options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = format_options;
            return writer.print("Color{{{d}, {d}, {d}}}", .{
                @intToFloat(f32, color.r) / 255,
                @intToFloat(f32, color.g) / 255,
                @intToFloat(f32, color.b) / 255,
            });
        }

        /// Returns whether this color is equal to the given color.
        pub fn eql(color: Color, other_color: Color) bool {
            return color.r == other_color.r and color.g == other_color.g and color.b == other_color.b;
        }

        pub fn vector(color: Color) @Vector(3, f32) {
            return @Vector(3, f32){ color.r, color.g, color.b };
        }

        const colors = struct {
            // all possible combinations of 0 and 1

            pub const red = Color.rgb(1, 0, 0);
            pub const green = Color.rgb(0, 1, 0);
            pub const blue = Color.rgb(0, 0, 1);

            pub const black = Color.rgb(0, 0, 0);
            pub const white = Color.rgb(1, 1, 1);

            pub const yellow = Color.rgb(1, 1, 0);
            pub const magenta = Color.rgb(1, 0, 1);
            pub const cyan = Color.rgb(0, 1, 1);
        };

        pub usingnamespace colors;

        /// Returns a `Color` from the red, green, and blue color primaries ranging from 0.0 to 1.0.
        pub fn rgb(red: anytype, green: anytype, blue: anytype) Color {
            assert(red >= 0 and red <= 1);
            assert(green >= 0 and green <= 1);
            assert(blue >= 0 and blue <= 1);
            if (options.round) {
                return .{
                    .r = @floatToInt(u8, @round(red * 255.0)),
                    .g = @floatToInt(u8, @round(green * 255.0)),
                    .b = @floatToInt(u8, @round(blue * 255.0)),
                };
            } else {
                return .{
                    .r = @floatToInt(u8, red * 255),
                    .g = @floatToInt(u8, green * 255),
                    .b = @floatToInt(u8, blue * 255),
                };
            }
        }

        /// Returns a `Color` from a color using the HSL color model.
        /// * `hue` is an angle in degrees from 0 to 360.
        /// * `saturation` and `lightness` are in range 0 to 1.
        ///
        /// As an example,
        /// * `hsl(0, 1.0, 0.5)` is red ({255, 0, 0} in RGB).
        /// * `hsl(0, 1.0, 1.0)` is white ({255, 255, 255} in RGB) because lightness is 100%.
        /// * `hsl(0, 1.0, 0.0)` is black ({0, 0, 0} in RGB) because lightness is 0%.
        ///
        /// So regardless of the other components, if lightness is 100%, it's always white,
        /// and if lightness is 0%, it's always black.
        ///
        /// If we turn the saturation down to `hsl(0, 0.25, 0.5)`, we will see a faint red.
        /// If we make the saturation zero (`hsl(0, 0.0, 0.5)`), we will get gray.
        ///
        /// Finally, the hue controls where we are on the color wheel;
        /// if we change 0 to 120 (`hsl(120, 1.0, 0.5)`), we get green.
        ///
        /// All this makes HSL an excellent color model for representing colors.
        /// Compared to RGB, it represents color in a natural way that is easier to understand.
        pub fn hsl(hue: anytype, saturation: anytype, lightness: anytype) Color {
            const h = hue;
            const s = saturation;
            const l = lightness;

            assert(h >= 0 and h <= 360);
            assert(s >= 0 and s <= 1);
            assert(l >= 0 and l <= 1);

            const a = s * math.min(l, 1 - l);
            return rgb(
                getHSLComponent(0, h, l, a),
                getHSLComponent(8, h, l, a),
                getHSLComponent(4, h, l, a),
            );
        }
        fn getHSLComponent(n: f32, h: f32, l: f32, a: f32) f32 {
            const k = @rem(n + h / 30, 12);
            return l - a * math.max(math.min3(k - 3, 9 - k, 1), -1);
        }

        const coloring = struct {
            // TODO: this is already defined in grids.zig
            const Content = *const fn (x: f32, y: f32) Color;

            pub fn solid(comptime color: Color) Content {
                return struct {
                    fn function(x: f32, y: f32) Cell {
                        _ = x;
                        _ = y;
                        return color;
                    }
                }.function;
            }

            // TODO: multiple colors by taking an array
            pub fn horizontalGradient(comptime from: Color, comptime to: Color) Content {
                return struct {
                    fn function(x: f32, y: f32) Cell {
                        _ = y;
                        switch (options.color_interpolation) {
                            .rgb => {
                                const result = lerp(
                                    @Vector(3, f32){ @intToFloat(f32, from.r), @intToFloat(f32, from.g), @intToFloat(f32, from.b) },
                                    @Vector(3, f32){ @intToFloat(f32, to.r), @intToFloat(f32, to.g), @intToFloat(f32, to.b) },
                                    @Vector(3, f32){ x, x, x },
                                );
                                return Color{
                                    .r = @floatToInt(u8, result[0]),
                                    .g = @floatToInt(u8, result[1]),
                                    .b = @floatToInt(u8, result[2]),
                                };
                            },
                            .hsv => {
                                const from_hsv = rgbToHsv(Color, f32, from);
                                const to_hsv = rgbToHsv(Color, f32, to);
                                const result = lerp(
                                    @Vector(3, f32){ from_hsv.h, from_hsv.s, from_hsv.v },
                                    @Vector(3, f32){ to_hsv.h, to_hsv.s, to_hsv.v },
                                    @Vector(3, f32){ x, x, x },
                                );
                                return hsvToRgb(Color, f32, .{
                                    .h = result[0],
                                    .s = result[1],
                                    .v = result[2],
                                });
                            },
                        }
                    }
                }.function;
            }

            pub fn verticalGradient(comptime from: Color, comptime to: Color) Content {
                return struct {
                    fn function(x: f32, y: f32) Cell {
                        _ = x;
                        switch (options.color_interpolation) {
                            .rgb => {
                                const result = lerp(
                                    @Vector(3, f32){ @intToFloat(f32, from.r), @intToFloat(f32, from.g), @intToFloat(f32, from.b) },
                                    @Vector(3, f32){ @intToFloat(f32, to.r), @intToFloat(f32, to.g), @intToFloat(f32, to.b) },
                                    @Vector(3, f32){ y, y, y },
                                );
                                return Color{
                                    .r = @floatToInt(u8, result[0]),
                                    .g = @floatToInt(u8, result[1]),
                                    .b = @floatToInt(u8, result[2]),
                                };
                            },
                            .hsv => {
                                const from_hsv = rgbToHsv(Color, f32, from);
                                const to_hsv = rgbToHsv(Color, f32, to);
                                const result = lerp(
                                    @Vector(3, f32){ from_hsv.h, from_hsv.s, from_hsv.v },
                                    @Vector(3, f32){ to_hsv.h, to_hsv.s, to_hsv.v },
                                    @Vector(3, f32){ y, y, y },
                                );
                                return hsvToRgb(Color, f32, .{
                                    .h = result[0],
                                    .s = result[1],
                                    .v = result[2],
                                });
                            },
                        }
                    }
                }.function;
            }
        };

        pub usingnamespace coloring;
    };
}

fn HSV(comptime Float: type) type {
    return struct {
        /// Hue.
        h: Float,
        /// Saturation.
        s: Float,
        /// Value.
        v: Float,
    };
}

pub fn rgbToHsv(comptime Cell: type, comptime Float: type, rgb: grids.Color(Cell)) HSV(Float) {
    const r = @intToFloat(Float, rgb.r) / 255;
    const g = @intToFloat(Float, rgb.g) / 255;
    const b = @intToFloat(Float, rgb.b) / 255;

    const max = math.max3(r, g, b);
    const min = math.min3(r, g, b);
    const diff = max - min;

    var hsv = HSV(Float){ .h = 0, .s = 0, .v = max };

    if (diff < math.f32_epsilon) {
        return hsv;
    } else {
        hsv.s = diff / max;
    }

    if (r >= max) {
        hsv.h = (g - b) / diff;
    } else if (g >= max) {
        hsv.h = 2 + (b - r) / diff;
    } else if (b >= max) {
        hsv.h = 4 + (r - g) / diff;
    } else {
        unreachable;
    }

    hsv.h *= 60;

    if (hsv.h < 0)
        hsv.h += 360;

    return hsv;
}

pub fn hsvToRgb(comptime Cell: type, comptime Float: type, hsv: HSV(Float)) grids.Color(Cell) {
    const Color = grids.Color(Cell);

    const h = hsv.h;
    const s = hsv.s;
    const v = hsv.v;

    assert(h >= 0 and h <= 360);
    assert(s >= 0 and s <= 1);
    assert(v >= 0 and v <= 1);

    if (s == 0)
        return Color.rgb(v, v, v);

    const hueNorm = h / 360;
    const i = @floatToInt(u8, hueNorm * 6);
    const f = hueNorm * 6 - @intToFloat(f32, i);
    const p = v * (1 - s);
    const q = v * (1 - (s * f));
    const t = v * (1 - (s * (1 - f)));

    return switch (i) {
        0 => Color.rgb(v, t, p),
        1 => Color.rgb(q, v, p),
        2 => Color.rgb(p, v, t),
        3 => Color.rgb(p, q, v),
        4 => Color.rgb(t, p, v),
        5 => Color.rgb(v, p, q),
        else => unreachable,
    };
}

const tests = struct {
    const Color = struct {
        r: u8,
        g: u8,
        b: u8,

        usingnamespace ColorHelpers(@This(), .{});
    };

    // this accomodates for rounding errors
    fn expectApproxEq(expected: Color, actual: Color) !void {
        try testing.expectApproxEqAbs(@intToFloat(f32, expected.r), @intToFloat(f32, actual.r), 1);
        try testing.expectApproxEqAbs(@intToFloat(f32, expected.g), @intToFloat(f32, actual.g), 1);
        try testing.expectApproxEqAbs(@intToFloat(f32, expected.b), @intToFloat(f32, actual.b), 1);
    }

    test "RGB colors" {
        try testing.expectEqual(Color{ .r = 0, .g = 0, .b = 0 }, Color.rgb(0, 0, 0));
        try testing.expectEqual(Color{ .r = 255, .g = 255, .b = 255 }, Color.rgb(1, 1, 1));

        try expectApproxEq(Color{ .r = 255, .g = 127, .b = 0 }, Color.rgb(1, 0.5, 0));
        try expectApproxEq(Color{ .r = 63, .g = 0, .b = 255 }, Color.rgb(0.25, 0, 1));
    }

    test "HSL colors" {
        try testing.expectEqual(Color.red, Color.hsl(0, 1.0, 0.5));
        try testing.expectEqual(Color.yellow, Color.hsl(60, 1.0, 0.5));
        try testing.expectEqual(Color.green, Color.hsl(120, 1.0, 0.5));
        try testing.expectEqual(Color.cyan, Color.hsl(180, 1.0, 0.5));
        try testing.expectEqual(Color.blue, Color.hsl(240, 1.0, 0.5));
        try testing.expectEqual(Color.magenta, Color.hsl(300, 1.0, 0.5));

        try testing.expectEqual(Color.black, Color.hsl(0, 1.0, 0.0));
        try testing.expectEqual(Color.white, Color.hsl(0, 1.0, 1.0));

        try testing.expectEqual(Color.rgb(0.5, 0.5, 0.5), Color.hsl(0, 0, 0.5));
    }

    test "HSV" {
        const colors = [_]Color{ Color.red, Color.green, Color.blue, Color.rgb(1, 0.5, 0.25), Color.rgb(0.25, 0.5, 1) };
        for (colors) |before| {
            const after = hsvToRgb(Color, f32, rgbToHsv(Color, f32, before));
            try expectApproxEq(before, after);
        }
    }
};

comptime {
    if (builtin.is_test)
        _ = tests;
}
