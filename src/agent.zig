const std = @import("std");
const info = @import("os/info.zig");
const Config = @import("types/config.zig").Config;
const SharedState = @import("types/shared_state.zig").SharedState;

pub fn run(io: std.Io, config: Config, state: *SharedState) anyerror!void {
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
