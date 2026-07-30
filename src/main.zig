const std = @import("std");

const info = @import("os/info.zig");
const zigzag = @import("zigzag");
const AppModel = @import("ui/agent.zig").AppModel;
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

    var future = io.async(runAgent, .{ io, config, &state });
    defer _ = future.cancel(io) catch {};

    var program = zigzag.Program(AppModel).init(init.gpa, init.io, init.environ_map);
    defer program.deinit();

    program.model.shared_state = &state;
    program.model.io = io;

    try program.run();

    _ = try future.cancel(io);
    _ = try future.await(io);
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

fn runAgent(io: std.Io, config: Config, state: *SharedState) !void {
    while (true) {
        try state.clearError(io);
        io.sleep(.fromSeconds(config.interval_secs), .awake) catch |err| {
            try state.setError(io, err);
            break;
        };
        const metrics = info.getMetrics(io) catch |err| {
            try state.setError(io, err);
            continue;
        };
        try state.set(io, metrics);
    }
}

test {
    _ = @import("os/info.zig");
    _ = @import("types/config.zig");
}
