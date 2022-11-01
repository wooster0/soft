const std = @import("std");
const builtin = @import("builtin");
const uefi = std.os.uefi;
const Status = uefi.Status;
const assert = std.debug.assert;

const wool = @import("wool");
const example = @import("example");
const other = @import("other");

pub const Grid = wool.DynamicGrid(.{
    .Cell = extern struct {
        // color component order is reversed: BGR instead of RGB
        b: u8,
        g: u8,
        r: u8,
        reserved: u8 = undefined,

        pub usingnamespace wool.ColorHelpers(@This(), .{});
    },
});
const Color = Grid.Cell;
pub var grid: Grid = undefined;

pub const allocator = uefi.pool_allocator;

pub var seed: u64 = undefined;

/// Returns a best-effort millisecond timestamp.
// TODO: PR this into std.time.nanoTimestamp() and or std.time.Instant.now()?
fn getMilliseconds() !f64 {
    var timestamp: uefi.Time = undefined;
    var capabilities: uefi.TimeCapabilities = undefined;
    if (uefi.system_table.runtime_services.getTime(&timestamp, &capabilities) != Status.Success)
        return error.FailedRetrievingTime;
    // TODO: improve this detection of broken nanosecond reporting
    return if (capabilities.resolution == 1)
        // this means the UEFI only supports reporting the time to the resolution of 1 second,
        // so `timestamp.nanosecond` will likely always be zero.
        // in this case we regard the UEFI's capability of reporting the nanosecond
        // as broken so we will use the next best thing we can.
        @intToFloat(f64, timestamp.second) * std.time.ms_per_s
    else
        @intToFloat(f64, timestamp.nanosecond) / std.time.ns_per_ms;
}

fn err(status: Status) ?Status {
    if (status != .Success)
        return status
    else
        return null;
}

pub fn main() Status {
    const boot_services = uefi.system_table.boot_services.?;

    var gop: *uefi.protocols.GraphicsOutputProtocol = undefined;
    if (err(boot_services.locateProtocol(
        &uefi.protocols.GraphicsOutputProtocol.guid,
        null,
        @ptrCast(*?*anyopaque, &gop),
    ))) |status| return status;

    // TODO: https://stackoverflow.com/questions/38979567/efi-graphics-output-protocol-blt-doesnt-do-anything
    //       should we locate all GOP protocol handles?

    // turn off the 5-minute timeout that would cause the system to reset.
    if (err(boot_services.setWatchdogTimer(0, 0, 0, null))) |status| return status;

    grid.cellsPtr = @intToPtr([*]Color, gop.mode.frame_buffer_base);
    grid.width = gop.mode.info.horizontal_resolution;
    grid.height = gop.mode.info.vertical_resolution;

    var back_buffer = Grid.init(allocator, grid.width, grid.height) catch return Status.OutOfResources;
    defer back_buffer.deinit(allocator);

    // select a display resolution
    {
        var sizes = allocator.alloc(wool.Size(u32), gop.mode.max_mode) catch return Status.OutOfResources;
        defer allocator.free(sizes);
        var mode: u32 = 0;
        var info_size: usize = undefined;
        var info: *uefi.protocols.GraphicsOutputModeInformation = undefined;
        while (mode < gop.mode.max_mode) : (mode += 1) {
            if (err(gop.queryMode(mode, &info_size, &info))) |status|
                return status;
            // TODO: if this is not true, we need to change a thing
            assert(info.pixels_per_scan_line == info.horizontal_resolution);
            sizes[mode] = .{ .width = info.horizontal_resolution, .height = info.vertical_resolution };

            // list all resolutions on the screen
            //grid.drawText(.{}, "{d}X{d}", .{ info.horizontal_resolution, info.vertical_resolution }, 100, 100 + mode * 10, Color.horizontalGradient(Color.red, Color.green)) catch unreachable;
        }

        // now that we collected all available options, we can choose a suitable size.
        // in this example we simply want to a size that's pretty small but not too small either.
        // you can apply more complicated logic.
        for (sizes) |size, index| {
            if (size.width >= 256 and size.height >= 256) {
                if (err(gop.setMode(@intCast(u32, index)))) |status|
                    return status;
                break;
            }
        }
    }

    _ = gop.setMode(1);

    seed = @bitCast(u64, getMilliseconds() catch 0);

    example.init() catch unreachable;

    var time = wool.Time{};

    while (true) {
        const now_ms = getMilliseconds() catch 0;
        if (now_ms != time.last_update_timestamp) {
            time.update(now_ms);
        } else {
            time.last_update_timestamp = now_ms;
        }

        back_buffer.fill(Color.black);
        grid = back_buffer;

        example.tick(time) catch return Status.Aborted;

        // TODO: measure performance (compare FPS?) between the following two solutions:
        // 1.: @memcpy(@intToPtr([*]u8, gop.mode.frame_buffer_base), @ptrCast([*]u8, grid.cells()), grid.len() * @sizeOf(Color));
        // 2.:
        if (err(
            gop.blt(@ptrCast(
                [*]uefi.protocols.GraphicsOutputBltPixel,
                back_buffer.cellsPtr,
            ), .BltBufferToVideo, 0, 0, 0, 0, grid.width, grid.height, 0),
        )) |status| return status;
    }
}
