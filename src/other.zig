//! Other, library-independent functionality.

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

// this is purposefully not used anywhere else in the library.
// it's not always a good idea to use this for general parameters in a library.
pub fn Size(comptime Int: type) type {
    return struct {
        width: Int,
        height: Int,

        const Self = @This();

        pub fn product(size: Self) Int {
            return size.width * size.height;
        }
    };
}

// this is purposefully not used anywhere else in the library.
// it's not always a good idea to use this for general parameters in a library.
pub fn Point(comptime Int: type) type {
    return struct { x: Int, y: Int };
}

// TODO: maybe compare this to std.math.lerp in the docs of this function,
//       depending on how this PR ends: https://github.com/ziglang/zig/pull/13002
/// Performs linear interpolation between *a* and *b* based on *t*.
/// *t* must be in range 0.0 to 1.0. Supports floats and vectors of floats.
///
/// This does not guarantee returning *b* if *t* is 1 due to floating-point errors.
/// This is monotonic.
pub fn lerp(a: anytype, b: anytype, t: anytype) @TypeOf(a, b, t) {
    const Type = @TypeOf(a, b, t);

    switch (@typeInfo(Type)) {
        .Float, .ComptimeFloat => assert(t >= 0 and t <= 1),
        .Vector => |vector| {
            const lower_bound = @reduce(.And, t >= @splat(vector.len, @as(vector.child, 0)));
            const upper_bound = @reduce(.And, t <= @splat(vector.len, @as(vector.child, 1)));
            assert(lower_bound and upper_bound);
        },
        else => comptime unreachable,
    }

    return @mulAdd(Type, b - a, t, a);
}


// TODO: pub fn Time(Float: type)
pub const Time = struct {
    /// Monotonically increasing time.
    elapsed: f64 = 0,
    /// This is the amount of seconds that have passed since the last time `update` was called.
    delta: f64 = 0,

    last_update_timestamp: f64 = 0,

    pub fn getFPS(time: Time) f64 {
        return 1.0 / time.delta;
    }

    /// Updates the time state using a timestamp of current time in milliseconds.
    ///
    /// This should be called at the start of every frame tick, before updating and drawing.
    ///
    /// Make sure the given current timestamp is not the same as the timestamp given at the previous update.
    pub fn update(time: *Time, now_ms: f64) void {
        // TODO: seems to be failing in the terminal example backend?
        // assert(now_ms != time.last_update_timestamp);
        time.delta = (now_ms - time.last_update_timestamp) /
            // this is what makes delta time seconds
            std.time.ms_per_s;
        time.last_update_timestamp = now_ms;
        time.elapsed += time.delta;
    }

    /// Returns the amount of nanoseconds required to sleep in order to cap the FPS at the given value.
    pub fn getFPSSleep(time: Time, fps: f64) ?u64 {
        const fraction: f64 = 1.0 / fps;
        if (time.delta < fraction)
            return @floatToInt(u64, std.time.ns_per_s * (fraction - time.delta))
        else
            return null;
    }

    // TODO: better name: "norm" or "scale"?
    /// Multiplies the value with delta time.
    /// This is important for motion consistent across different framerates.
    pub fn mul(time: Time, value: anytype, factor: f64) @TypeOf(value) {
        const Type = @TypeOf(value);
        comptime if (std.meta.trait.isIntegral(Type)) {
            return @floatToInt(Type, @intToFloat(f64, value) * time.delta * factor);
        } else if (std.meta.trait.isFloat(Type)) {
            return @floatCast(Type, @floatCast(f64, value) * time.delta * factor);
        };
    }
};

test "lerp" {
    try testing.expectEqual(@as(f64, 75), lerp(50, 100, 0.5));
    try testing.expectEqual(@as(f32, 43.75), lerp(50, 25, 0.25));
    try testing.expectEqual(@as(f64, -31.25), lerp(-50, 25, 0.25));

    try testing.expectApproxEqRel(@as(f32, -7.16067345e+03), lerp(-10000.12345, -5000.12345, 0.56789), 1e-19);
    try testing.expectApproxEqRel(@as(f64, 7.010987590521e+62), lerp(0.123456789e-64, 0.123456789e64, 0.56789), 1e-33);

    try testing.expectEqual(@as(f32, 0.0), lerp(@as(f32, 1.0e8), 1.0, 1.0));
    try testing.expectEqual(@as(f64, 0.0), lerp(@as(f64, 1.0e16), 1.0, 1.0));
    try testing.expectEqual(@as(f32, 1.0), lerp(@as(f32, 1.0e7), 1.0, 1.0));
    try testing.expectEqual(@as(f64, 1.0), lerp(@as(f64, 1.0e15), 1.0, 1.0));

    try testing.expectEqual(
        lerp(@splat(3, @as(f32, 0)), @splat(3, @as(f32, 50)), @splat(3, @as(f32, 0.5))),
        @Vector(3, f32){ 25, 25, 25 },
    );
    try testing.expectEqual(
        lerp(@splat(3, @as(f64, 50)), @splat(3, @as(f64, 100)), @splat(3, @as(f64, 0.5))),
        @Vector(3, f64){ 75, 75, 75 },
    );
}
