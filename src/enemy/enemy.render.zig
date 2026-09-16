// Draws a live enemy; a defeated one simply stops drawing.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("enemy.types.zig");

const SPRITE = sprite_mod.fromArt(&.{
    "#..#..#.",
    ".######.",
    "##.##.##",
    "########",
    "########",
    ".######.",
    "#.#..#.#",
    "........",
});

pub fn draw(enemy: types.Enemy) void {
    if (!enemy.alive) return;
    w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3]
    SPRITE.draw(@intFromFloat(enemy.x), @intFromFloat(enemy.y), !enemy.facing_right);
}
