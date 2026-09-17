// Debug-only run-state accessors for tools/wasm4-harness.js -- plain
// `pub fn`s; main.zig exports them as WASM only in Debug builds.

const char_types = @import("character/character.types.zig");
const map_types = @import("map/map.types.zig");
const key_types = @import("key/key.types.zig");
const state = @import("game/game.types.zig");

pub fn getHp() callconv(.c) i32 {
    return char_types.player.hp;
}

pub fn getScore() callconv(.c) u32 {
    return char_types.player.score;
}

pub fn isGameOver() callconv(.c) u32 {
    return @intFromBool(state.game.game_over);
}

pub fn getPlayerX() callconv(.c) i32 {
    return @intFromFloat(char_types.player.x);
}

pub fn getPlayerY() callconv(.c) i32 {
    return @intFromFloat(char_types.player.y);
}

pub fn getRoomIndex() callconv(.c) u32 {
    return map_types.room_index;
}

pub fn getTransitionActive() callconv(.c) u32 {
    return @intFromBool(map_types.transition.active);
}

pub fn getTransitionFrame() callconv(.c) u32 {
    return map_types.transition.frame;
}

// 0=floor, 1=ceiling, 2=left_wall, 3=right_wall, 4=airborne (no surface).
pub fn getSurface() callconv(.c) u32 {
    const s = char_types.player.surface orelse return 4;
    return switch (s) {
        .floor => 0,
        .ceiling => 1,
        .left_wall => 2,
        .right_wall => 3,
    };
}

pub fn getKeyCollected() callconv(.c) u32 {
    return @intFromBool(key_types.active.collected);
}

