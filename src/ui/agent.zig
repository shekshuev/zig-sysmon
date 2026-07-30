const std = @import("std");
const zigzag = @import("zigzag");

const SystemMetrics = @import("../types/system_metrics.zig").SystemMetrics;
const SharedState = @import("../types/shared_state.zig").SharedState;

pub const AppModel = struct {
    shared_state: *SharedState = undefined,
    io: std.Io = undefined,
    metrics: ?SystemMetrics = null,

    pub const Msg = union(enum) {
        key: zigzag.KeyEvent,
        tick: struct {
            timestamp: i64,
            delta: u64,
        },
    };

    pub fn init(self: *AppModel, ctx: *zigzag.Context) zigzag.Cmd(Msg) {
        _ = ctx;
        _ = self;
        return zigzag.Cmd(Msg).everyMs(500);
    }

    pub fn update(self: *AppModel, msg: Msg, ctx: *zigzag.Context) zigzag.Cmd(Msg) {
        _ = ctx;
        switch (msg) {
            .key => |k| {
                switch (k.key) {
                    .char => |c| if (c == 'q') return .quit,
                    else => {},
                }
            },
            .tick => {
                if (self.shared_state.get(self.io) catch null) |fresh| {
                    self.metrics = fresh;
                }
            },
        }
        return .none;
    }

    pub fn view(self: *const AppModel, ctx: *const zigzag.Context) []const u8 {
        const alloc = ctx.allocator;

        if (self.shared_state.getError(self.io) catch null) |err| {
            const err_msg = std.fmt.allocPrint(alloc, "Error: {s}", .{@errorName(err)}) catch "Error occurred";
            return zigzag.place.place(alloc, ctx.width, ctx.height, .left, .top, err_msg) catch "Layout error";
        }

        if (self.metrics) |m| {
            const host = std.mem.sliceTo(&m.hostname, 0);
            const os_rel = std.mem.sliceTo(&m.os_release, 0);
            const kern = std.mem.sliceTo(&m.kern_version, 0);

            const ram_total_gb = m.ram_total / (1024 * 1024 * 1024);
            const ram_used_bytes = m.ram_total -| m.ram_available;
            const ram_used_gb = ram_used_bytes / (1024 * 1024 * 1024);

            const ram_pct: f32 = if (m.ram_total > 0)
                @floatFromInt((ram_used_bytes * 100) / m.ram_total)
            else
                0.0;

            var gauge = zigzag.Gauge{};
            gauge.label = "RAM";
            gauge.width = 30;
            gauge.value = ram_pct;
            gauge.show_percent = true;
            gauge.display_style = .bar;
            const ram_gauge_str = gauge.view(alloc);

            const hours = m.uptime_secs / 3600;
            const mins = (m.uptime_secs % 3600) / 60;

            const content = std.fmt.allocPrint(alloc,
                \\  SYS-MONITOR
                \\  ──────────────────────────────────────
                \\  Host:       {s}
                \\  OS:         {s}
                \\  Kernel:     {s}
                \\  CPU Cores:  {d}
                \\  Uptime:     {d}h {d}m
                \\  ──────────────────────────────────────
                \\  Memory:     {d}/{d} GB
                \\  {s}
                \\  ──────────────────────────────────────
                \\  [q] Quit
            , .{
                host,
                os_rel,
                kern,
                m.cpu_cores,
                hours,
                mins,
                ram_used_gb,
                ram_total_gb,
                ram_gauge_str,
            }) catch "Error formatting dashboard";

            return zigzag.place.place(alloc, ctx.width, ctx.height, .left, .top, content) catch "Layout error";
        }

        return zigzag.place.place(alloc, ctx.width, ctx.height, .left, .top, "Waiting for agent metrics...") catch "Loading...";
    }
};
