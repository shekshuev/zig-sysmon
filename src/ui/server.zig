const std = @import("std");
const zigzag = @import("zigzag");

const SharedState = @import("../types/shared_state.zig").SharedState;

pub fn init(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    state: *SharedState,
) zigzag.Program(AppModel) {
    var program = zigzag.Program(AppModel).init(allocator, io, env);
    program.model.shared_state = state;
    program.model.io = io;
    return program;
}

const AppModel = struct {
    shared_state: *SharedState = undefined,
    io: std.Io = undefined,

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
        _ = self;
        switch (msg) {
            .key => |k| {
                switch (k.key) {
                    .char => |c| if (c == 'q') return .quit,
                    else => {},
                }
            },
            .tick => {},
        }
        return .none;
    }

    pub fn view(self: *const AppModel, ctx: *const zigzag.Context) []const u8 {
        const alloc = ctx.allocator;

        if (self.shared_state.getError(self.io) catch null) |err| {
            const err_msg = std.fmt.allocPrint(alloc, "Error: {s}", .{@errorName(err)}) catch "Error occurred";
            return zigzag.place.place(alloc, ctx.width, ctx.height, .left, .top, err_msg) catch "Layout error";
        }

        const content = std.fmt.allocPrint(alloc,
            \\  SYS-MONITOR SERVER
            \\  ──────────────────────────────────────
            \\  Not implemented
            \\  ──────────────────────────────────────
            \\  [q] Quit
        , .{}) catch "Error formatting dashboard";

        return zigzag.place.place(alloc, ctx.width, ctx.height, .left, .top, content) catch "Layout error";
    }
};
