//! OpenGL has two profiles: Compatibility and Core.
//! Core is the modern one with the old stuff from before shaders etc. removed and
//! Compatibility is backwards-compatible and still has all the deprecated stuff.
//! Here we will use Compatibility mode and its ancient functions for, you guessed it, compatibility,
//! and simplicity because we don't need to load pointers to OpenGL functions at runtime, either.
//!
//! You might also be interested in:
//! * https://www.khronos.org/opengl/wiki/History_of_OpenGL
//! * https://www.khronos.org/opengl/wiki/OpenGL_Loading_Library

// TODO: add a Core profile version without an additional dependency like GLAD or GLEW?
//       but it might be a bad idea:
// > accessing the gl function pointers is not difficult. It is platform dependent and it is tedious. That's why glad etc exist.

const std = @import("std");

const soft = @import("soft");
const example = @import("example");
const other = @import("other");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const Grid = soft.DynamicGrid(.{
    .Cell = extern struct {
        r: u8,
        g: u8,
        b: u8,

        pub usingnamespace soft.ColorHelpers(@This(), .{});
    },
});
const Color = Grid.Cell;
pub var grid: Grid = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub var seed: u64 = undefined;

const initial_window_size = 512;

fn errorCallback(code: c_int, description: [*c]const u8) callconv(.C) void {
    std.debug.panic("GLFW error: {s} ({d})\n", .{ description, code });
}

var resize: ?soft.Size(usize) = null;

fn windowSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    resize = .{
        .width = @as(c_uint, @intCast(width)),
        .height = @as(c_uint, @intCast(height)),
    };
}

pub fn main() !void {
    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == c.GLFW_FALSE)
        @panic("failed initializing GLFW");
    defer {
        // this will destroy any remaining windows as well
        // so we don't need to call `glfwDestroyWindow` manually
        c.glfwTerminate();
    }

    const window = createWindow();

    // run at the monitor's refresh rate
    c.glfwSwapInterval(1);

    grid = try Grid.init(allocator, initial_window_size, initial_window_size);
    defer grid.deinit(allocator);

    seed = @as(u64, @bitCast(std.time.milliTimestamp()));

    try example.init();

    var time = soft.Time{};

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        time.update(@as(f64, @floatFromInt(std.time.milliTimestamp())));

        // no sleep needed: we rely VSync to run the example at a reasonable speed

        // it's best to handle resizes in an ordered manner so we do it here
        if (resize) |size| {
            // TODO: dynamically resize the grid:
            //       try grid.resize(allocator, size.width, size.height);

            c.glViewport(0, 0, @as(c_int, @intCast(size.width)), @as(c_int, @intCast(size.height)));

            resize = null;
        }

        const maybe_clear_color = if (@hasDecl(example, "clear_color")) example.clear_color else Color.black;
        if (@as(?Color, maybe_clear_color)) |clear_color|
            grid.fill(clear_color);

        try example.tick(time);

        draw();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

fn createWindow() *c.GLFWwindow {
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);

    const window = c.glfwCreateWindow(initial_window_size, initial_window_size, "Soft example", null, null) orelse {
        @panic("failed creating window");
    };
    c.glfwMakeContextCurrent(window);

    _ = c.glfwSetWindowSizeCallback(window, windowSizeCallback);

    return window;
}

fn draw() void {
    c.glRasterPos2i(-1, 1);
    c.glPixelZoom(1, -1);
    c.glDrawPixels(
        @as(c_int, @intCast(grid.width)),
        @as(c_int, @intCast(grid.height)),
        c.GL_RGB,
        c.GL_UNSIGNED_BYTE,
        @as(?*const anyopaque, @ptrCast(grid.cells())),
    );
}
