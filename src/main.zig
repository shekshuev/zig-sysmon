const std = @import("std");

const info = @import("os/info.zig");
const zigzag = @import("zigzag");
const AppModel = @import("ui/agent.zig").AppModel;
const Config = @import("types/config.zig").Config;
const SharedState = @import("types/shared_state.zig").SharedState;

pub fn main(init: std.process.Init) !void {
    const config = try Config.load(init.minimal.args, init.minimal.environ);
    const io = init.io;

    var state: SharedState = .{};

    var future = io.async(runAgent, .{ io, config, &state });
    defer _ = future.cancel(io) catch {};

    var program = zigzag.Program(AppModel).init(init.gpa, init.io, init.environ_map);
    defer program.deinit();

    program.model.shared_state = &state;
    program.model.io = io;

    try program.run();

    // info.waitForSignal();

    // std.debug.print("\nReleasing resources...\n", .{});

    _ = try future.cancel(io);
    _ = try future.await(io);

    // std.debug.print("Goodbye.\n", .{});
}

fn runAgent(io: std.Io, config: Config, state: *SharedState) !void {
    while (true) {
        io.sleep(.fromSeconds(config.interval_secs), .awake) catch {
            // std.debug.print("Agent has stopped.\n", .{});
            break;
        };
        const metrics = info.getMetrics(io) catch {
            // std.debug.print("Error retrieving metrics: {s}. Skipping iteration...\n", .{@errorName(err)});
            continue;
        };
        try state.set(io, metrics);
    }
}

test {
    _ = @import("os/info.zig");
}
