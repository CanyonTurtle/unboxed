// Entry point: wires WASM4's start/update exports to game.sim/game.render.
// Deliberately thin -- see CLAUDE.md for why nothing but wiring belongs here.

const builtin = @import("builtin");
const w4 = @import("wasm4.zig");
const debug = @import("debug.zig");
const game_sim = @import("game/game.sim.zig");
const game_render = @import("game/game.render.zig");

// Debug-only WASM exports for the JS test harness (tools/wasm4-harness.js)
// to drive; only compiled into Debug builds, so a release build stays minimal.
comptime {
    if (builtin.mode == .Debug) {
        @export(&debug.getHp, .{ .name = "debugGetHp" });
        @export(&debug.getScore, .{ .name = "debugGetScore" });
        @export(&debug.isGameOver, .{ .name = "debugIsGameOver" });
        @export(&debug.getPlayerX, .{ .name = "debugGetPlayerX" });
        @export(&debug.getPlayerY, .{ .name = "debugGetPlayerY" });
        @export(&debug.getRoomX, .{ .name = "debugGetRoomX" });
        @export(&debug.getRoomY, .{ .name = "debugGetRoomY" });
    }
}

export fn start() void {
    w4.PALETTE.* = .{ 0x1a1c2c, 0xf4f4f4, 0x3a4466, 0xb13e53 };
    game_sim.newRun();
}

export fn update() void {
    const gamepad = w4.GAMEPAD1.*;
    game_sim.update(gamepad);
    game_render.draw();
}
