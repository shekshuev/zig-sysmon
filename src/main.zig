const std = @import("std");

const info = @import("os/info.zig");
const zigzag = @import("zigzag");
const agent = @import("agent.zig");
const server = @import("server.zig");
const agent_ui = @import("ui/agent.zig");
const server_ui = @import("ui/server.zig");
const Config = @import("types/config.zig").Config;
const SharedState = @import("types/shared_state.zig").SharedState;

pub fn main(init: std.process.Init) !void {
    const config = Config.load(init.minimal.args, init.minimal.environ) catch |err| {
        switch (err) {
            error.MissingArgument => std.debug.print("Error: missing argument value.\n\n", .{}),
            error.InvalidArgument => std.debug.print("Error: wrong argument type.\n\n", .{}),
        }
        printUsage();
        std.process.exit(1);
    };
    const io = init.io;

    var state: SharedState = .{};

    var future = io.async(runWorker, .{ io, config, &state });
    defer _ = future.cancel(io) catch {};

    switch (config.mode) {
        .agent => {
            var program = agent_ui.init(init.gpa, io, init.environ_map, &state);
            defer program.deinit();
            try program.run();
        },
        .server => {
            var program = server_ui.init(init.gpa, io, init.environ_map, &state);
            defer program.deinit();
            try program.run();
        },
    }

    _ = try future.cancel(io);
    _ = try future.await(io);
}

fn runWorker(io: std.Io, config: Config, state: *SharedState) anyerror!void {
    switch (config.mode) {
        .agent => try agent.run(io, config, state),
        .server => try server.run(io, config, state),
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage: zig_sysmon [MODE] [OPTIONS]
        \\
        \\Modes:
        \\  agent (default)         Launch agent to retrive metrics
        \\  server                  Launch server
        \\
        \\Options:
        \\  -h, --host <HOST>       Hostname or IP (default: localhost)
        \\  -p, --port <PORT>       Port (default: 1429)
        \\  -i, --interval <SECS>   Metrics retrieval interval in seconds (default: 2)
        \\
    , .{});
}

test {
    _ = @import("os/info.zig");
    _ = @import("types/config.zig");
}
