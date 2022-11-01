//! A simple HTTP 1.1 webserver for development.

// TODO: add something like hot code reloading?
//       make it possible to tell this webserver about Wasm files that are supposed to be rebuilt
//       if a source code file has changed (so it watches those).

const std = @import("std");
const mem = std.mem;
const net = std.net;
const log = std.log;

pub const log_level = if (@import("builtin").mode == .Debug) .debug else .info;

const media_types = std.ComptimeStringMap([]const u8, .{
    .{ .@"0" = "html", .@"1" = "text/html" },
    .{ .@"0" = "css", .@"1" = "text/css" },
    .{ .@"0" = "js", .@"1" = "text/javascript" },
    .{ .@"0" = "wasm", .@"1" = "application/wasm" },
    .{ .@"0" = "ico", .@"1" = "image/x-icon" },
    .{ .@"0" = "otf", .@"1" = "font/otf" },
    .{ .@"0" = "png", .@"1" = "image/png" },
});

pub fn main() u8 {
    var args = std.process.argsWithAllocator(std.heap.page_allocator) catch |err| {
        log.err("failed reading args: {s}", .{@errorName(err)});
        return 1;
    };
    _ = args.skip(); // skip program name
    if (args.next()) |dir_path| {
        run(dir_path) catch return 1;
    } else {
        log.info("no dir given; serving .", .{});
        run("") catch return 1;
    }
    return 0;
}

pub fn run(dir_path: []const u8) !void {
    var trimmed_dir_path = mem.trimRight(u8, dir_path, "/");
    if (trimmed_dir_path.len == 0) {
        trimmed_dir_path = ".";
    } else {
        const stat = std.fs.cwd().statFile(trimmed_dir_path) catch |err| {
            log.err("failed checking that dir path points to dir: {s}", .{@errorName(err)});
            return error.Error;
        };
        if (stat.kind != .Directory) {
            log.err("dir path does not point to dir: {s}", .{trimmed_dir_path});
            return error.Error;
        }
    }

    var stream_server = net.StreamServer.init(.{
        // this is useful if the server has been shut down and then restarted right away while sockets
        // are still active on the same port
        .reuse_address = true,
    });

    stream_server.listen(net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080)) catch |err| {
        log.err("failed listening at localhost:8080: {s}", .{@errorName(err)});
        return error.Error;
    };

    log.info("open <http://localhost:8080/> in your browser", .{});

    while (true) {
        const connection = stream_server.accept() catch |err| {
            log.warn("failed accepting new connection: {s}", .{@errorName(err)});
            continue;
        };
        defer connection.stream.close();

        log.info("new connection from {} with handle {}", .{ connection.address, connection.stream.handle });

        serve(connection.stream, trimmed_dir_path) catch |err| {
            log.warn("failed serving request: {s}", .{@errorName(err)});
            continue;
        };
    }
}

fn serve(stream: net.Stream, trimmed_dir_path: []const u8) !void {
    // https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#HTTP/1.1_request_messages
    // https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#HTTP/1.1_response_messages

    const reader = stream.reader();
    var buffered_writer = std.io.bufferedWriter(stream.writer());
    const writer = buffered_writer.writer();

    var buf: [256]u8 = undefined;

    // if the delimiter is not followed by '\n', that's ok too
    const request_line = try reader.readUntilDelimiterOrEof(&buf, '\r') orelse return error.StreamTooLong;

    var parts = mem.split(u8, request_line, " ");
    const method = parts.first();
    if (!mem.eql(u8, method, "GET")) {
        log.warn("only GET requests allowed; got {s}", .{method});
        return error.BadRequestMethod;
    }

    var trimmed_file_path = mem.trimLeft(u8, parts.next() orelse return error.MissingPath, "/");
    if (trimmed_file_path.len == 0)
        trimmed_file_path = "index.html";
    var path: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const absolute_path = try std.fmt.bufPrint(&path, "{s}/{s}", .{ trimmed_dir_path, trimmed_file_path });

    // discard the remaining data to avoid a connection reset
    while (true) if (try reader.read(&buf) < buf.len) break;

    log.info("serving {s}", .{absolute_path});
    const file = try std.fs.cwd().openFile(absolute_path, .{});
    const content_type = content_type: {
        const file_ext_start = mem.lastIndexOfScalar(u8, absolute_path, '.') orelse return error.InvalidFileName;
        const file_ext = absolute_path[file_ext_start + 1 ..];
        break :content_type media_types.get(file_ext) orelse {
            log.warn("unknown media type for file extension {s}; sending empty Content-Type", .{file_ext});
            break :content_type "";
        };
    };
    const content_length = (try file.metadata()).size();
    // we need to use CRLF line endings so we combine carriage returns with the newlines
    try writer.print(
        \\HTTP/1.1 200 OK{[cr]c}
        \\Content-Type: {[content_type]s}{[cr]c}
        \\Content-Length: {[content_length]d}{[cr]c}
        \\{[cr]c}
        \\
    , .{
        .content_type = content_type,
        .content_length = content_length,
        .cr = '\r',
    });

    while (true) {
        const len = try file.readAll(&buf);
        try writer.writeAll(buf[0..len]);
        if (len < buf.len) break;
    }

    try buffered_writer.flush();
}
