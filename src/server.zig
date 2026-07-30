const std = @import("std");
const info = @import("os/info.zig");
const Config = @import("types/config.zig").Config;
const SharedState = @import("types/shared_state.zig").SharedState;

pub fn run(io: std.Io, config: Config, state: *SharedState) anyerror!void {
    _ = io;
    _ = config;
    _ = state;
    std.debug.print("Not implemented", .{});
}
