const std = @import("std");
const testing = std.testing;
const info = @import("../os/info.zig");

pub const Mode = enum {
    agent,
    server,
};

const env_mode = "SM_MODE";
const env_host = "SM_HOST";
const env_port = "SM_PORT";
const env_interval_secs = "SM_INTERVAL_SECS";

pub const ConfigError = error{
    MissingArgument,
    InvalidArgument,
};

pub const Config = struct {
    pub const default_host = "localhost";
    pub const default_port: u16 = 1429;
    pub const default_interval_secs: u32 = 2;

    mode: Mode, // "agent" or "server"
    host: []const u8, // i.e. localhost for server mode
    port: u16, // i.e. 8000 for server mode
    interval_secs: u32, // i.e. 2 for agent mode, how often get stats

    pub fn load(args: std.process.Args, environ: std.process.Environ) !Config {
        var config = Config{
            .mode = Mode.agent,
            .host = default_host,
            .port = default_port,
            .interval_secs = default_interval_secs,
        };

        if (info.getEnviron(environ, env_mode)) |value| {
            if (std.meta.stringToEnum(Mode, value)) |m| {
                config.mode = m;
            }
        }

        if (info.getEnviron(environ, env_host)) |value| {
            if (value.len > 0 and value.len <= 253) {
                config.host = value;
            }
        }

        if (info.getEnviron(environ, env_port)) |value| {
            if (value.len > 0) {
                config.port = std.fmt.parseInt(u16, value, 10) catch config.port;
            }
        }

        if (info.getEnviron(environ, env_interval_secs)) |value| {
            if (value.len > 0) {
                config.interval_secs = std.fmt.parseInt(u32, value, 10) catch config.interval_secs;
            }
        }

        var iter = args.iterate();

        _ = iter.next(); // app name

        while (iter.next()) |key| {
            if (!std.mem.startsWith(u8, key, "-")) {
                config.mode = std.meta.stringToEnum(Mode, key) orelse config.mode;
                continue;
            } else if (std.mem.eql(u8, key, "--host") or std.mem.eql(u8, key, "-h")) {
                const value = iter.next() orelse return error.MissingArgument;

                if (std.mem.startsWith(u8, value, "-")) {
                    return error.MissingArgument;
                }

                if (value.len > 0 and value.len <= 253) {
                    config.host = value;
                }
            } else if (std.mem.eql(u8, key, "--port") or std.mem.eql(u8, key, "-p")) {
                const value = iter.next() orelse return error.MissingArgument;

                if (std.mem.startsWith(u8, value, "-")) {
                    return error.MissingArgument;
                }

                config.port = std.fmt.parseInt(u16, value, 10) catch return error.InvalidArgument;
            } else if (std.mem.eql(u8, key, "--interval") or std.mem.eql(u8, key, "-i")) {
                const value = iter.next() orelse return error.MissingArgument;

                if (std.mem.startsWith(u8, value, "-")) {
                    return error.MissingArgument;
                }

                config.interval_secs = std.fmt.parseInt(u32, value, 10) catch return error.InvalidArgument;
            }
        }

        return config;
    }
};

test "config loads default values" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{"zig_sysmon"},
    };
    const dummy_env = std.process.Environ{ .block = .empty };

    const config = try Config.load(dummy_args, dummy_env);

    try testing.expectEqual(Config.default_host, config.host);
    try testing.expectEqual(Config.default_port, config.port);
    try testing.expectEqual(Config.default_interval_secs, config.interval_secs);
    try testing.expectEqual(Mode.agent, config.mode);
}

test "config load env values and overrides defaults" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{"zig_sysmon"},
    };
    const env_vars = [_:null]?[*:0]const u8{
        "SM_MODE=server",
        "SM_HOST=127.0.0.1",
        "SM_PORT=9000",
        "SM_INTERVAL_SECS=5",
    };

    const dummy_env = std.process.Environ{
        .block = .{ .slice = &env_vars },
    };

    const config = try Config.load(dummy_args, dummy_env);

    try testing.expectEqualStrings("127.0.0.1", config.host);
    try testing.expectEqual(9000, config.port);
    try testing.expectEqual(5, config.interval_secs);
    try testing.expectEqual(Mode.server, config.mode);
}

test "config load args values and overrides defaults" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{
            "zig_sysmon",
            "server",
            "--port",
            "9000",
            "--host",
            "127.0.0.1",
            "--interval",
            "5",
        },
    };
    const dummy_env = std.process.Environ{ .block = .empty };

    const config = try Config.load(dummy_args, dummy_env);

    try testing.expectEqualStrings("127.0.0.1", config.host);
    try testing.expectEqual(9000, config.port);
    try testing.expectEqual(5, config.interval_secs);
    try testing.expectEqual(Mode.server, config.mode);
}

test "config returns missing argument error if arg value is missing " {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{
            "zig_sysmon",
            "server",
            "--port",
            "--host",
            "127.0.0.1",
            "--interval",
            "5",
        },
    };
    const dummy_env = std.process.Environ{ .block = .empty };

    const config = Config.load(dummy_args, dummy_env);

    try testing.expectError(error.MissingArgument, config);
}

test "config returns invalid argument error if arg value mismatch expected type" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{
            "zig_sysmon",
            "server",
            "--port",
            "eight_zero_zero_zero",
            "--host",
            "127.0.0.1",
            "--interval",
            "5",
        },
    };
    const dummy_env = std.process.Environ{ .block = .empty };

    const config = Config.load(dummy_args, dummy_env);

    try testing.expectError(error.InvalidArgument, config);
}

test "config load args (short) values and overrides defaults" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{
            "zig_sysmon",
            "server",
            "-p",
            "9000",
            "-h",
            "127.0.0.1",
            "-i",
            "5",
        },
    };
    const dummy_env = std.process.Environ{ .block = .empty };

    const config = try Config.load(dummy_args, dummy_env);

    try testing.expectEqualStrings("127.0.0.1", config.host);
    try testing.expectEqual(9000, config.port);
    try testing.expectEqual(5, config.interval_secs);
    try testing.expectEqual(Mode.server, config.mode);
}

test "config load args and env values and args overrides all" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{
            "zig_sysmon",
            "server",
            "--port",
            "9000",
            "--host",
            "127.0.0.1",
            "--interval",
            "5",
        },
    };
    const env_vars = [_:null]?[*:0]const u8{
        "SM_MODE=agent",
        "SM_HOST=127.0.0.2",
        "SM_PORT=9001",
        "SM_INTERVAL_SECS=50",
    };

    const dummy_env = std.process.Environ{
        .block = .{ .slice = &env_vars },
    };

    const config = try Config.load(dummy_args, dummy_env);

    try testing.expectEqualStrings("127.0.0.1", config.host);
    try testing.expectEqual(9000, config.port);
    try testing.expectEqual(5, config.interval_secs);
    try testing.expectEqual(Mode.server, config.mode);
}

test "config load args and env values and use defaults if nothing passed" {
    const dummy_args = std.process.Args{
        .vector = &[_][*:0]const u8{
            "zig_sysmon",
            "--port",
            "9000",
            "server",
        },
    };
    const env_vars = [_:null]?[*:0]const u8{
        "SM_HOST=127.0.0.2",
    };

    const dummy_env = std.process.Environ{
        .block = .{ .slice = &env_vars },
    };

    const config = try Config.load(dummy_args, dummy_env);

    try testing.expectEqualStrings("127.0.0.2", config.host);
    try testing.expectEqual(9000, config.port);
    try testing.expectEqual(2, config.interval_secs);
    try testing.expectEqual(Mode.server, config.mode);
}
