const std = @import("std");

const soft = @import("soft");
const example = @import("example");
const other = @import("other");

const c = @import("c.zig");

const App = @import("App.zig");

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

    var window = createWindow();

    // TODO: this doesn't work in Vulkan! figure out how to do this in Vulkan
    // // attempt to turn on vertical synchronization which may limit the FPS to 60 for example
    // c.glfwSwapInterval(1);

    // vulkan.createInstance();
    // TODO: make all GLFW stuff part of this too? and then move glfwTerminate to this deinit etc.
    const app = try App.init(allocator, window);
    defer app.deinit();
    std.debug.print("successfully created Vulkan-capable app!\n", .{});

    grid = try Grid.init(allocator, initial_window_size, initial_window_size);
    defer grid.deinit(allocator);

    seed = @as(u64, @bitCast(std.time.milliTimestamp()));

    try example.init();

    var time = soft.Time{};

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        time.update(@as(f64, @floatFromInt(std.time.milliTimestamp())));
        // no sleep: we rely on the system to run this example at a reasonable pace

        // // it's best to handle resizes in an ordered manner so we do it here
        // if (resize) |size| {
        //     // TODO: try grid.resize(allocator, size.width, size.height);
        //
        //     c.glViewport(0, 0, @intCast(c_int, size.width), @intCast(c_int, size.height));
        //
        //     resize = null;
        // }

        grid.fill(Color.black);

        try example.tick(time);

        // TODO(remove): grid.drawText(.{}, "FPS {d}", .{time.getFPS()}, 0, 0, Color.solid(Color.red)) catch unreachable;

        // c.glClear(c.GL_COLOR_BUFFER_BIT);
        // draw();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

fn createWindow() *c.GLFWwindow {
    // don't create an OpenGL context
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE); // TODO: c.GLFW_TRUE later

    const window = c.glfwCreateWindow(initial_window_size, initial_window_size, "Soft example", null, null) orelse {
        @panic("failed creating GLFW window");
    };
    // c.glfwMakeContextCurrent(window); // TODO: don't need this for Vulkan?

    _ = c.glfwSetWindowSizeCallback(window, windowSizeCallback);

    return window;
}
