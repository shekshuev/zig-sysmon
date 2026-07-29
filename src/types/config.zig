const std = @import("std");

const info = @import("../os/info.zig");

pub const Mode = enum {
    agent,
    server,
};

const env_mode = "SM_MODE";
const env_host = "SM_HOST";
const env_port = "SM_PORT";
const env_interval_secs = "SM_INTERVAL_SECS";

pub const Config = struct {
    pub const default_host = "localhost";
    pub const default_port: u16 = 1409;
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
                if (iter.next()) |value| {
                    if (value.len > 0 and value.len <= 253) {
                        config.host = value;
                    }
                }
            } else if (std.mem.eql(u8, key, "--port") or std.mem.eql(u8, key, "-p")) {
                if (iter.next()) |value| {
                    config.port = std.fmt.parseInt(u16, value, 10) catch config.port;
                }
            } else if (std.mem.eql(u8, key, "--interval") or std.mem.eql(u8, key, "-i")) {
                if (iter.next()) |value| {
                    config.interval_secs = std.fmt.parseInt(u32, value, 10) catch config.interval_secs;
                }
            }
        }

        return config;
    }
};
