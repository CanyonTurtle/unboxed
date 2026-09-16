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

pub fn draw(enemy: types.Enemy, offset_x: i32, offset_y: i32) void {
    if (!enemy.alive) return;
    w4.DRAW_COLORS.* = 0x0030; // color2 = palette[2] (red)
    const x: i32 = @as(i32, @intFromFloat(enemy.x)) + offset_x;
    const y: i32 = @as(i32, @intFromFloat(enemy.y)) + offset_y;
    SPRITE.draw(x, y, !enemy.facing_right);
}
