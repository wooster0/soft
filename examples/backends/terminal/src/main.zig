const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const io = std.io;
const fmt = std.fmt;
const ascii = std.ascii;
const assert = std.debug.assert;

const wool = @import("wool");
const example = @import("example");
const other = @import("other");

const Size = wool.Size;

pub const Grid = wool.DynamicGrid(.{
    .Cell = packed struct {
        r: u8,
        g: u8,
        b: u8,

        pub usingnamespace wool.ColorHelpers(@This(), .{});
    },
});
const Color = Grid.Cell;
pub var grid: Grid = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub var seed: u64 = undefined;

const renderer: union(enum) {
    /// Uses '▀' and '▄' to render.
    half_block,
    /// Uses custom characters to render.
    /// Use this if you can't see '▀' and '▄' or if the half block renderer is too slow.
    custom: struct { string: []const u8 = "██", width: usize = 2 },
} = .half_block;

// TODO: handle terminal window resizes to resize the grid (SIGWINCH etc.)

const Terminal = struct {
    /// Control Sequence Indicator.
    const CSI = "\x1b[";

    /// Operating System Command.
    const OSC = "\x1b]";

    const BufferedWriter = io.BufferedWriter(
        // the larger this buffer size, the less flickering we will see when drawing
        // and the better the performance. bump this up if needed.
        200 * 1000, // 200KB
        std.fs.File.Writer,
    );

    stdout: std.fs.File,
    buffered_writer: BufferedWriter,

    pub fn init() error{unsupported}!Terminal {
        const stdout = io.getStdOut();
        if (!stdout.supportsAnsiEscapeCodes())
            return error.unsupported;
        return .{
            .stdout = stdout,
            .buffered_writer = BufferedWriter{ .unbuffered_writer = stdout.writer() },
        };
    }

    pub fn print(terminal: *Terminal, comptime format: []const u8, args: anytype) !void {
        try terminal.buffered_writer.writer().print(format, args);
    }

    /// In debug mode we record the highest amount of bytes encountered before flushing.
    /// This is useful when optimizing code to output less bytes.
    var flush_max_bytes: usize = 0;

    pub fn flush(terminal: *Terminal) !void {
        if (builtin.mode == .Debug) {
            if (terminal.buffered_writer.end > flush_max_bytes)
                flush_max_bytes = terminal.buffered_writer.end;
        }
        try terminal.buffered_writer.flush();
    }

    pub fn enableAlternateScreenBuffer(terminal: *Terminal) !void {
        try terminal.print(CSI ++ "?1049h", .{});
    }
    pub fn disableAlternateScreenBuffer(terminal: *Terminal) !void {
        try terminal.print(CSI ++ "?1049l", .{});
    }

    pub fn setCursorPosition(terminal: *Terminal, x: u16, y: u16) !void {
        try terminal.print(CSI ++ "{};{}H", .{ y + 1, x + 1 });
    }

    pub fn setForegroundColor(terminal: *Terminal, r: u8, g: u8, b: u8) !void {
        try terminal.print(CSI ++ "38;2;{};{};{}m", .{ r, g, b });
    }
    pub fn setBackgroundColor(terminal: *Terminal, r: u8, g: u8, b: u8) !void {
        try terminal.print(CSI ++ "48;2;{};{};{}m", .{ r, g, b });
    }

    /// Resets all terminal attributes.
    pub fn reset(terminal: *Terminal) !void {
        try terminal.print(CSI ++ "m", .{});
    }

    pub fn showCursor(terminal: *Terminal) !void {
        try terminal.print(CSI ++ "?25h", .{});
    }
    pub fn hideCursor(terminal: *Terminal) !void {
        try terminal.print(CSI ++ "?25l", .{});
    }

    pub fn clear(terminal: *Terminal) !void {
        try terminal.print(CSI ++ "2J", .{});
    }

    pub fn setTitle(terminal: *Terminal, comptime format: []const u8, args: anytype) !void {
        try terminal.print(OSC ++ "0;" ++ format ++ [1]u8{ascii.control_code.bel}, args);
    }

    pub fn getSize(terminal: Terminal) !Size(u16) {
        if (builtin.os.tag == .linux) {
            var winsize: os.linux.winsize = undefined;
            switch (os.errno(os.linux.ioctl(terminal.stdout.handle, os.linux.T.IOCGWINSZ, @ptrToInt(&winsize)))) {
                .SUCCESS => return .{ .width = winsize.ws_col, .height = winsize.ws_row },
                else => return error.unexpected,
            }
        } else if (builtin.os.tag == .windows) {
            var info: os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (os.windows.kernel32.GetConsoleScreenBufferInfo(terminal.stdout, &info) != os.windows.TRUE)
                return error.unexpected;
            return .{ .width = @intCast(u16, info.dwSize.X), .height = @intCast(u16, info.dwSize.Y) };
        }
    }

    /// Sets a persistent background color of the whole terminal using a hexadecimal color.
    pub fn setScreenBackgroundColor(terminal: *Terminal, hex_color: []const u8) !void {
        assert(fmt.parseUnsigned(u24, hex_color, 16) catch null != null);
        try terminal.print(OSC ++ "11;#{s}" ++ [1]u8{ascii.control_code.bel}, .{hex_color});
    }
    pub fn resetScreenBackgroundColor(terminal: *Terminal) !void {
        try terminal.print(OSC ++ "111" ++ [1]u8{ascii.control_code.bel}, .{});
    }

    /// Sets a persistent foreground color of the whole terminal using a hexadecimal color.
    pub fn setScreenForegroundColor(terminal: *Terminal, hex_color: []const u8) !void {
        assert(fmt.parseUnsigned(u24, hex_color, 16) catch null != null);
        try terminal.print(OSC ++ "10;#{s}" ++ [1]u8{ascii.control_code.bel}, .{hex_color});
    }
    pub fn resetScreenForegroundColor(terminal: *Terminal) !void {
        try terminal.print(OSC ++ "110" ++ [1]u8{ascii.control_code.bel}, .{});
    }

    pub fn pause() void {
        _ = try io.getStdIn().reader().readByte();
    }
};

fn drawGrid(terminal: *Terminal) !void {
    switch (renderer) {
        .half_block => {
            var index: usize = 0;
            while (index < grid.len()) : (index += 1) {
                if (index != 0 and index % grid.width == 0) {
                    // skip this row; we iterate two rows at a time
                    index += grid.width;
                    if (index >= grid.len()) break;
                }

                const upper_cell = grid.cellsSlice()[index];
                const upper_color = if (upper_cell.eql(Color.black))
                    null
                else
                    upper_cell;

                const x = @intCast(u16, index % grid.width);
                const y = @intCast(u16, index / grid.width);

                const lower_color = if (grid.get(@intCast(i16, x), @intCast(i16, y) + 1)) |color_cell|
                    if (color_cell.eql(Color.black))
                        null
                    else
                        color_cell
                else
                    null;

                if (upper_color == null and lower_color == null)
                    // this cell is empty
                    continue;

                try terminal.setCursorPosition(x, y / 2);

                if (upper_color == null and lower_color != null) {
                    try terminal.setForegroundColor(lower_color.?.r, lower_color.?.g, lower_color.?.b);
                    try terminal.print("▄", .{});
                } else if (upper_color != null and lower_color == null) {
                    try terminal.setForegroundColor(upper_color.?.r, upper_color.?.g, upper_color.?.b);
                    try terminal.print("▀", .{});
                } else if (upper_color != null and lower_color != null) {
                    try terminal.setForegroundColor(upper_color.?.r, upper_color.?.g, upper_color.?.b);
                    try terminal.setBackgroundColor(lower_color.?.r, lower_color.?.g, lower_color.?.b);
                    try terminal.print("▀", .{});
                    // TODO: benchmark whether it's faster to reset only the foreground color
                    //       instead of resetting all terminal attributes (maybe just check the flushed bytes).
                    //       if it is, add resetForegroundColor and resetBackgroundColor.
                    try terminal.reset();
                }
            }
        },
        .custom => |string| {
            for (grid.cellsSlice()) |color, index| {
                if (color.eql(Color.black)) continue;

                const x = @intCast(u16, index % grid.width);
                const y = @intCast(u16, index / grid.width);

                // TODO: open an issue? string length should be comptime_int
                try terminal.setCursorPosition(x * @as(u16, string.width), y);
                try terminal.setForegroundColor(color.r, color.g, color.b);
                try terminal.print("{s}", .{string.string});
            }
        },
    }
}

// TODO: PR this if https://github.com/ziglang/zig/issues/13045 is accepted
/// Registers a handler to be run if an abort signal is catched.
/// The abort signal is usually fired if Ctrl+C is pressed in a terminal.
///
/// Use this for non-critical cleanups or resets of terminal state and such.
/// The handler is not guaranteed to be run.
fn setAbortSignalHandler(comptime handler: *const fn () void) !void {
    if (builtin.os.tag == .windows) {
        const handler_routine = struct {
            fn handler_routine(dwCtrlType: os.windows.DWORD) callconv(os.windows.WINAPI) os.windows.BOOL {
                if (dwCtrlType == os.windows.CTRL_C_EVENT) {
                    handler();
                    return os.windows.TRUE;
                } else {
                    return os.windows.FALSE;
                }
            }
        }.handler_routine;
        try os.windows.SetConsoleCtrlHandler(handler_routine, true);
    } else {
        const internal_handler = struct {
            fn internal_handler(sig: c_int) callconv(.C) void {
                assert(sig == os.SIG.INT);
                handler();
            }
        }.internal_handler;
        const act = os.Sigaction{
            .handler = .{ .handler = internal_handler },
            .mask = os.empty_sigset,
            .flags = 0,
        };
        try os.sigaction(os.SIG.INT, &act, null);
    }
}

fn handleAbortSignal() void {
    reset_terminal: {
        // just create another Terminal to clean up
        var terminal = Terminal.init() catch |err| {
            switch (err) {
                // we've already initialized it once, so we know it is supported
                error.unsupported => unreachable,
            }
        };
        terminal.disableAlternateScreenBuffer() catch break :reset_terminal;
        terminal.showCursor() catch break :reset_terminal;
        // the title resets itself
        terminal.resetScreenBackgroundColor() catch break :reset_terminal;
        terminal.flush() catch break :reset_terminal;
    }

    if (builtin.mode == .Debug)
        // TODO: investigate why there's a newline after this
        //       (expected is that we would need to put it ourselves)
        std.debug.print("record amount of bytes flushed: {d}", .{Terminal.flush_max_bytes});

    os.exit(0);
}

fn run() !void {
    var terminal = try Terminal.init();

    // note that you can resize your terminal or change your terminal font size to see more cells
    const terminalSize = try terminal.getSize();
    grid = switch (renderer) {
        .half_block => try Grid.init(
            allocator,
            terminalSize.width,
            terminalSize.height * 2,
        ),
        .custom => |string| try Grid.init(
            allocator,
            terminalSize.width / @as(u16, string.width),
            terminalSize.height,
        ),
    };
    defer grid.deinit(allocator);

    try terminal.enableAlternateScreenBuffer();
    try terminal.hideCursor();
    try terminal.setTitle("Wool example", .{});

    try setAbortSignalHandler(handleAbortSignal);

    seed = @bitCast(u64, std.time.milliTimestamp());

    try example.init();

    const maybe_clear_color = if (@hasDecl(example, "clear_color")) example.clear_color else Color.black;
    if (@as(?Color, maybe_clear_color)) |clear_color| {
        var hex_color: [6]u8 = undefined;
        try terminal.setScreenBackgroundColor(
            try fmt.bufPrint(&hex_color, "{x:0<2}{x:0<2}{x:0<2}", .{
                clear_color.r,
                clear_color.g,
                clear_color.b,
            }),
        );
    }

    var time = wool.Time{};

    while (true) {
        time.update(@intToFloat(f64, std.time.milliTimestamp()));
        if (time.getFPSSleep(60)) |ns|
            std.time.sleep(ns);

        // TODO: detect whether a cell was drawn to or not differently. currently it is not possible
        //       to draw black. Maybe add a field to `packed struct` above to mark it as "not drawn to",
        //       or make Cell optional. then this would be `grid.fill(null);` to indicate that all cells
        //       have not been drawn to
        grid.fill(Color.black);

        try example.tick(time);

        try terminal.clear();
        try drawGrid(&terminal);
        try terminal.flush();
    }
}

pub fn main() u8 {
    run() catch |err| {
        switch (err) {
            error.unsupported => io.getStdErr().writeAll("unsupported environment\n") catch {},
            else => io.getStdErr().writeAll("unknown error\n") catch {},
        }
        return 1;
    };
    return 0;
}
