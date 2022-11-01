const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const testing = std.testing;

pub const StaticGrid = @import("grids.zig").StaticGrid;
pub const DynamicGrid = @import("grids.zig").DynamicGrid;
pub const ColorHelpers = @import("grids.zig").ColorHelpers;
pub const BitMap = @import("grids.zig").BitMap;
// TODO: pub const Sprite = @import("grids.zig").Sprite;

pub usingnamespace @import("other.zig");

comptime {
    if (builtin.is_test)
        _ = @import("grids.zig");
}
