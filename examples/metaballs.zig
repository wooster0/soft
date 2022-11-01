//! These are metaballs, not to be confused with meatballs: <https://en.wikipedia.org/wiki/Metaballs>.
//! For brevity we will call them balls in this file.

const std = @import("std");
const builtin = @import("builtin");

const wool = @import("wool");
const backend = @import("backend");

const Grid = backend.Grid;
const grid = &backend.grid;
const Color = Grid.Cell;

const Ball = struct {
    x: isize,
    y: isize,
    dx: isize,
    dy: isize,
};

/// The balls. Adjust the length for more or less balls!
var balls: [10]Ball = undefined;

/// The smaller this value, the larger the balls.
/// Note that radii individual to balls are not possible.
const ball_threshold: f32 = 100;
/// This adds a distinctly visible border made of horizontal lines around the balls.
/// Make this 0 to turn it off.
const ball_border_radius: f32 = 25;

pub fn init() !void {
    var prng = std.rand.DefaultPrng.init(backend.seed);
    const random = prng.random();
    for (balls) |*ball| {
        ball.x = random.intRangeAtMost(isize, 0, @intCast(isize, grid.width));
        ball.y = random.intRangeAtMost(isize, 0, @intCast(isize, grid.height));
        ball.dx = if (random.boolean()) -1 else 1;
        ball.dy = if (random.boolean()) -1 else 1;
    }
}

pub const clear_color = Color.white;

pub fn tick(time: anytype) !void {
    // move the balls
    for (balls) |*ball| {
        if (ball.x + ball.dx >= grid.width or ball.x + ball.dx < 0)
            ball.dx *= -1;
        if (ball.y + ball.dy >= grid.height or ball.y + ball.dy < 0)
            ball.dy *= -1;
        // TODO: time.mul?
        ball.x += ball.dx;
        ball.y += ball.dy;
    }

    const fluctuation = 15;
    const fluctuation_speed = 5;

    const size = @intToFloat(f32, grid.width * grid.height);
    const current_ball_threshold = @floatCast(f32, (ball_threshold + @sin(time.elapsed * fluctuation_speed) * fluctuation) / size);
    const current_ball_border_radius = @floatCast(f32, (ball_border_radius + @sin(time.elapsed * fluctuation_speed) * fluctuation) / size);

    var x: isize = 0;
    while (x < grid.width) : (x += 1) {
        var y: isize = 0;
        while (y < grid.height) : (y += 1) {
            var sum: f32 = 0;
            for (balls) |ball| {
                sum += 1 / @intToFloat(
                    f32,
                    (x - ball.x) * (x - ball.x) + (y - ball.y) * (y - ball.y),
                );
            }

            const current_threshold: f32 =
                if (@rem(x, 2) == 0)
                current_ball_threshold
            else
                current_ball_threshold + current_ball_border_radius;
            if (sum > current_threshold) {
                grid.set(
                    x,
                    y,
                    Color.rgb(
                        @intToFloat(f32, x) / @intToFloat(f32, grid.width),
                        @intToFloat(f32, y) / @intToFloat(f32, grid.height),
                        @fabs(@sin(time.elapsed)),
                    ),
                );
            }
        }
    }
}
