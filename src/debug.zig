// Debug-only run-state accessors for tools/wasm4-harness.js -- plain
// `pub fn`s; main.zig exports them as WASM only in Debug builds.

const char_types = @import("character/character.types.zig");
const map_types = @import("map/map.types.zig");
const platform_types = @import("platform/platform.types.zig");
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

pub fn getRoomX() callconv(.c) u32 {
    return map_types.current_rx;
}

pub fn getRoomY() callconv(.c) u32 {
    return map_types.current_ry;
}

pub fn getPlatformX() callconv(.c) i32 {
    return @intFromFloat(platform_types.platforms[0].body.x);
}

pub fn getPlatformY() callconv(.c) i32 {
    return @intFromFloat(platform_types.platforms[0].body.y);
}
