//! Grids serve for the storage of cells and they come along with functionality to draw cells to those grids.
//!
//! If you specified a color cell to `Options.Cell`, you might also call those grids the framebuffer or the bitmap
//! because they serve as a memory buffer for video data.

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const assert = std.debug.assert;
const testing = std.testing;

const other = @import("other.zig");

pub const DynamicGrid = @import("grids/dynamic.zig").DynamicGrid;
pub const StaticGrid = @import("grids/static.zig").StaticGrid;
pub const BitMap = @import("grids/bit_map.zig").BitMap;
// TODO: pub const Sprite = @import("grids/sprite.zig").Sprite;

pub const ColorHelpers = @import("grids/color_helpers.zig").ColorHelpers;

const DrawingHelpers = @import("grids/drawing/helpers.zig").DrawingHelpers;
const Shapes = @import("grids/drawing/shapes.zig").Shapes;
const Text = @import("grids/drawing/text.zig").Text;

const Backend = union(enum) {
    setCell: *const fn () void,
    default,
    terminal,
};

// TODO: should each grid have its own Options? with some fundamental options required to be supported by all grid kinds
/// Grid configuration. This allows you to customize your grid which affects your drawing results and such.
///
/// All fields are provided with default values tuned for the best results, with a good balance between
/// quality and performance. Adjust values as you see need.
pub const Options = struct {
    // TODO: allow a custom `set` function to be passed here
    /// The cell that the grid will be filled with.
    ///
    /// There are two kinds of cells:
    /// * Color cells.
    /// * Custom cells.
    ///
    /// # Color cell
    ///
    /// A cell is a **color cell** if this struct has the fields `r: u8`, `g: u8`, and `b: u8`,
    /// specifying the red, green, and blue color primaries, respectively.
    /// This is true color, a color depth of 24 bits.
    /// To quote <https://en.wikipedia.org/wiki/Color_depth#True_color_(24-bit)>:
    ///
    /// > As of 2018, 24-bit color depth is used by virtually every computer and phone display and the vast majority of image storage formats.
    ///
    /// Color cells qualify for usage with color helpers; include them as such:
    /// ```zig
    ///     pub usingnamespace ColorHelpers(@This());
    /// ```
    ///
    /// You can use the default value of this field as a reference.
    /// Here is what you could do to this struct:
    ///
    /// * Add an additional field like `alpha: u8`.
    ///   Sometimes this may be required simply for compatibility.
    /// * Make the struct `packed`:
    ///   sometimes this may be required simply for compatibility.
    ///   Additionally, making the struct tightly packed with no padding may have the advantage
    ///   of using less memory which could be beneficial especially if you have a lot of pixels.
    ///   This may improve performance but could very well also worsen performance;
    ///   be sure to benchmark appropriately.
    /// * Make the struct an optional:
    ///   this is one way to allow you to check whether you've already drawn to a cell in the grid or not.
    /// * Make the struct an enum such as `enum { empty, filled }`:
    ///   this is useful if you're working with bit maps or have a specific set of colors and such.
    /// * Change the field order:
    ///   some environments may need a specific byte order such as BGR because of differences in endianness and such.
    ///   You will probably want to combine this with making the struct packed.
    ///
    /// # Custom cell
    ///
    /// If you don't provide a struct with the fields `r: u8`, `g: u8`, and `b: u8`,
    /// this cell is a **custom cell**.
    /// Custom cells are incompatible with `ColorHelpers` and other parts of the library that depend
    /// on true color.
    Cell: type = struct {
        r: u8,
        g: u8,
        b: u8,

        pub usingnamespace ColorHelpers(@This(), .{});
    },
    /// This defines **out of bounds** behavior for `set`, the fundamental draw function that others are based on.
    /// Out of bounds happens when a cell is placed outside of the grid's boundaries.
    oob_behavior: enum {
        /// If a cell crosses the grid's horizontal boundary (its width), it will not show up.
        /// If a cell crosses the grid's vertical boundary (its height), it will not show up.
        /// This means it will cause anything outside the grid to simply not show up.
        /// This is recommended because it is the most graceful option and usually looks the best.
        ///
        /// This avoids any possible draw operation crashes.
        clip,
        /// If a cell crosses the grid's horizontal boundary,
        /// it will wrap around and draw on the next line.
        /// This may be slightly faster than `clip`.
        ///
        /// This avoids any possible draw operation crashes.
        wrap,
        /// The behavior for best performance in non-safe release modes.
        /// On OOB in safe build modes this will still crash with an error
        /// but cause undefined behavior in non-safe release modes.
        /// Use this if you don't expect things drawn to the screen to cross the grid's boundaries.
        fast,
    } = .clip,
};

pub fn Color(comptime Cell: type) type {
    var seen_r = false;
    var seen_g = false;
    var seen_b = false;
    for (@typeInfo(Cell).Struct.fields) |field| {
        if (mem.eql(u8, field.name, "r") and field.type == u8)
            seen_r = true
        else if (mem.eql(u8, field.name, "g") and field.type == u8)
            seen_g = true
        else if (mem.eql(u8, field.name, "b") and field.type == u8)
            seen_b = true;
    }

    if (seen_r and seen_g and seen_b)
        return Cell
    else
        // zig fmt: off
        @compileError(
            \\cell is not a color cell
                ++ (if (seen_r) "" else "\ncell struct is missing `r: u8`")
                ++ (if (seen_g) "" else "\ncell struct is missing `g: u8`")
                ++ (if (seen_b) "" else "\ncell struct is missing `b: u8`")
        );
        // zig fmt: on
}

/// All types that qualify as grids have this imported.
pub fn Imports(comptime Grid: type, comptime options: Options) type {
    return struct {
        pub const Cell = options.Cell;
        pub const Content = *const fn (x: f32, y: f32) options.Cell;

        pub usingnamespace DrawingHelpers(Grid, options);
        pub usingnamespace Shapes(Grid, options);
        pub usingnamespace Text(Grid, options);
    };
}

comptime {
    if (builtin.is_test) {
        _ = @import("grids/color_helpers.zig");
        _ = @import("grids/drawing/shapes.zig");
        _ = @import("grids/bit_map.zig");
    }
}
