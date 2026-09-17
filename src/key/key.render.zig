// Draws a placed, uncollected key -- the room's objective, so it's drawn
// in the same yellow as the player to read as "the thing you want".

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("key.types.zig");

const SPRITE = sprite_mod.fromArt(&.{
    ".##.....",
    "#..#....",
    "#..#....",
    ".##.....",
    "..##....",
    "..##.##.",
    "..#####.",
    "........",
});

pub fn draw(key: types.Key, offset_x: i32, offset_y: i32) void {
    if (!key.placed or key.collected) return;
    w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3] (yellow)
    SPRITE.draw(@as(i32, @intFromFloat(key.x)) + offset_x, @as(i32, @intFromFloat(key.y)) + offset_y, false);
}
