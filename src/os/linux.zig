const std = @import("std");
const posix = std.posix;
const Io = std.Io;
const testing = std.testing;

const SystemMetrics = @import("../types/system_metrics.zig").SystemMetrics;

extern "c" fn sigwait(set: *const std.posix.sigset_t, sig: *c_int) c_int;

pub fn getMetrics(io: Io) !SystemMetrics {
    var hostname_buf: [posix.HOST_NAME_MAX]u8 = [_]u8{0} ** posix.HOST_NAME_MAX;
    _ = try posix.gethostname(&hostname_buf);

    const cpu_count = try std.Thread.getCpuCount();
    const kern_version = posix.uname();

    const total_memory = try getTotalMemory(io);
    const available_memory = try getAvailableMemory(io);

    const uptime = try getUptime(io);
    const os_release = try getOsRelease(io);

    return SystemMetrics{
        .hostname = hostname_buf,
        .ram_total = total_memory,
        .ram_available = available_memory,
        .cpu_cores = @intCast(cpu_count),
        .uptime_secs = uptime,
        .os_release = os_release,
        .kern_version = kern_version.release,
    };
}

pub fn getEnviron(environ: std.process.Environ, key: []const u8) ?[]const u8 {
    return environ.getPosix(key);
}

pub fn waitForSignal() void {
    var mask = std.mem.zeroes(std.posix.sigset_t);
    std.posix.sigaddset(&mask, std.posix.SIG.INT);
    std.posix.sigaddset(&mask, std.posix.SIG.TERM);
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, null);

    var sig: c_int = 0;
    _ = sigwait(&mask, &sig);
}

fn getTotalMemory(io: Io) !u64 {
    var buf: [512]u8 = undefined;
    const content = try std.Io.Dir.cwd().readFile(io, "/proc/meminfo", &buf);

    return try parseMeminfoValueByKey(content, "MemTotal:");
}

fn getAvailableMemory(io: Io) !u64 {
    var buf: [512]u8 = undefined;
    const content = try std.Io.Dir.cwd().readFile(io, "/proc/meminfo", &buf);

    return try parseMeminfoValueByKey(content, "MemAvailable:");
}

fn parseMeminfoValueByKey(content: []const u8, key: []const u8) !u64 {
    if (std.mem.indexOf(u8, content, key)) |start_idx| {
        const rest = content[start_idx + key.len ..];
        var tokens = std.mem.tokenizeAny(u8, rest, " \t\r\n");
        if (tokens.next()) |num_str| {
            const kb = try std.fmt.parseInt(u64, num_str, 10);
            return kb * 1024;
        }
    }
    return 0;
}

fn getUptime(io: Io) !u64 {
    var buf: [512]u8 = undefined;
    const content = try std.Io.Dir.cwd().readFile(io, "/proc/uptime", &buf);

    return parseUptime(content);
}

fn parseUptime(content: []const u8) u64 {
    if (std.mem.indexOf(u8, content, " ")) |start_idx| {
        const str_value = content[0..start_idx];
        const float_value = std.fmt.parseFloat(f64, str_value) catch 0;
        return @intFromFloat(float_value);
    }
    return 0;
}

fn getOsRelease(io: Io) ![64]u8 {
    var buf: [512]u8 = undefined;
    const content = try std.Io.Dir.cwd().readFile(io, "/etc/os-release", &buf);

    return parseOsRelease(content);
}

fn parseOsRelease(content: []const u8) [64]u8 {
    var result: [64]u8 = [_]u8{0} ** 64;
    if (std.mem.indexOf(u8, content, "PRETTY_NAME=")) |start_idx| {
        const rest = content[start_idx + "PRETTY_NAME=".len ..];
        const line_end = std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len;
        const name = rest[0..line_end];
        const clear_name = std.mem.trim(u8, name, "\"");
        const copy_len = @min(clear_name.len, result.len);
        @memcpy(result[0..copy_len], clear_name[0..copy_len]);
    }
    return result;
}

test "parseUptime should return zero if value not presented" {
    const proc_uptime = " 18714.00";
    const result = parseUptime(proc_uptime);

    const expected = 0;
    try testing.expectEqual(expected, result);
}

test "parseUptime should correctly ejects uptime float value" {
    const proc_uptime = "1307.63 18714.00";
    const result = parseUptime(proc_uptime);

    const expected = 1307;
    try testing.expectEqual(expected, result);
}

test "parseUptime should return zero if empty string passed as content" {
    const proc_uptime = "";
    const result = parseUptime(proc_uptime);

    const expected = 0;
    try testing.expectEqual(expected, result);
}

test "parseUptime should return zero if value before space is not a float" {
    const proc_uptime = "corrupted_value 18714.00";
    const result = parseUptime(proc_uptime);

    try testing.expectEqual(0, result);
}

test "parseMeminfoValueByKey should correctly eject MemTotal in bytes" {
    const mock_meminfo =
        \\MemTotal:       15659196 kB
        \\MemFree:          865868 kB
        \\MemAvailable:    7601868 kB
    ;

    const result = try parseMeminfoValueByKey(mock_meminfo, "MemTotal:");
    const expected_bytes: u64 = 15659196 * 1024;
    try testing.expectEqual(expected_bytes, result);
}

test "parseMeminfoValueByKey should correctly eject MemAvailable in bytes" {
    const mock_meminfo =
        \\MemTotal:       15659196 kB
        \\MemFree:          865868 kB
        \\MemAvailable:    7601868 kB
    ;

    const result = try parseMeminfoValueByKey(mock_meminfo, "MemAvailable:");
    const expected_bytes: u64 = 7601868 * 1024;
    try testing.expectEqual(expected_bytes, result);
}

test "parseMeminfoValueByKey should return zero if key not presented" {
    const mock_meminfo =
        \\MemTotal:       15659196 kB
        \\MemFree:          865868 kB
        \\MemAvailable:    7601868 kB
    ;

    const result = try parseMeminfoValueByKey(mock_meminfo, "SomeWrongKey:");
    try testing.expectEqual(0, result);
}

test "parseMeminfoValueByKey should return zero if content is empty" {
    const mock_meminfo = "";

    const result = try parseMeminfoValueByKey(mock_meminfo, "MemTotal:");
    try testing.expectEqual(0, result);
}

test "parseMeminfoValueByKey should return error if MemTotal value is missing" {
    const mock_meminfo =
        \\MemTotal:       kB
        \\MemFree:          865868 kB
        \\MemAvailable:    7601868 kB
    ;

    const result = parseMeminfoValueByKey(mock_meminfo, "MemTotal:");
    try testing.expectError(error.InvalidCharacter, result);
}

test "parseMeminfoValueByKey should return error if MemTotal value is not number" {
    const mock_meminfo =
        \\MemTotal:      some kB
        \\MemFree:          865868 kB
        \\MemAvailable:    7601868 kB
    ;

    const result = parseMeminfoValueByKey(mock_meminfo, "MemTotal:");
    try testing.expectError(error.InvalidCharacter, result);
}

test "parseOsRelease should correctly parse release name" {
    const mock_os_release =
        \\PRETTY_NAME="Ubuntu 25.10"
        \\NAME="Ubuntu"
        \\VERSION_ID="25.10"
        \\VERSION="25.10 (Questing Quokka)"
        \\VERSION_CODENAME=questing
        \\ID=ubuntu
        \\ID_LIKE=debian
        \\HOME_URL="https://www.ubuntu.com/"
        \\SUPPORT_URL="https://help.ubuntu.com/"
        \\BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
        \\PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
        \\UBUNTU_CODENAME=questing
        \\LOGO=ubuntu-logo
    ;
    const result = parseOsRelease(mock_os_release);
    const release_str = std.mem.sliceTo(&result, 0);
    const expected_release = "Ubuntu 25.10";
    try testing.expectEqualStrings(expected_release, release_str);
}

test "parseOsRelease should truncate string if PRETTY_NAME exceeds 64 chars" {
    const long_name = "A" ** 100;

    const mock_os_release = "PRETTY_NAME=\"" ++ long_name ++ "\"\n" ++
        \\NAME="Ubuntu"
        \\VERSION_ID="25.10"
        \\VERSION="25.10 (Questing Quokka)"
        \\VERSION_CODENAME=questing
        \\ID=ubuntu
        \\ID_LIKE=debian
        \\HOME_URL="https://www.ubuntu.com/"
        \\SUPPORT_URL="https://help.ubuntu.com/"
        \\BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
        \\PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
        \\UBUNTU_CODENAME=questing
        \\LOGO=ubuntu-logo
    ;
    const result = parseOsRelease(mock_os_release);

    const expected = "A" ** 64;

    try testing.expectEqualStrings(expected, &result);
}

test "parseOsRelease should return zero-filled buffer if PRETTY_NAME is missing" {
    const mock_os_release =
        \\NO_PRETTY_NO_NAME="Ubuntu 25.10"
        \\NAME="Ubuntu"
        \\VERSION_ID="25.10"
        \\VERSION="25.10 (Questing Quokka)"
        \\VERSION_CODENAME=questing
        \\ID=ubuntu
        \\ID_LIKE=debian
        \\HOME_URL="https://www.ubuntu.com/"
        \\SUPPORT_URL="https://help.ubuntu.com/"
        \\BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
        \\PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
        \\UBUNTU_CODENAME=questing
        \\LOGO=ubuntu-logo
    ;
    const result = parseOsRelease(mock_os_release);
    const expected: [64]u8 = [_]u8{0} ** 64;
    try testing.expectEqual(expected, result);
}

test "parseOsRelease should return zero-filled buffer if /etc/os-release is empty" {
    const mock_os_release = "";
    const result = parseOsRelease(mock_os_release);
    const expected: [64]u8 = [_]u8{0} ** 64;
    try testing.expectEqual(expected, result);
}

test "parseOsRelease should correctly parse release name when content doesn't contain \\n at the end" {
    const mock_os_release = "PRETTY_NAME=\"Ubuntu 25.10\"";
    const result = parseOsRelease(mock_os_release);
    const release_str = std.mem.sliceTo(&result, 0);
    const expected_release = "Ubuntu 25.10";
    try testing.expectEqualStrings(expected_release, release_str);
}

test "parseOsRelease should return zero-filled buffer if PRETTY_NAME is empty string" {
    const mock_os_release = "PRETTY_NAME=\"\"";
    const result = parseOsRelease(mock_os_release);
    const expected: [64]u8 = [_]u8{0} ** 64;

    try testing.expectEqual(expected, result);
}
