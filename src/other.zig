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
            return @intFromFloat(std.time.ns_per_s * (fraction - time.delta))
        else
            return null;
    }

    // TODO: better name: "norm" or "scale"?
    /// Multiplies the value with delta time.
    /// This is important for motion consistent across different framerates.
    pub fn mul(time: Time, value: anytype, factor: f64) @TypeOf(value) {
        const Type = @TypeOf(value);
        comptime if (std.meta.trait.isIntegral(Type)) {
            return @intFromFloat(@as(f64, @floatFromInt(value)) * time.delta * factor);
        } else if (std.meta.trait.isFloat(Type)) {
            return @floatCast(@as(f64, @floatCast(value)) * time.delta * factor);
        };
    }
};
