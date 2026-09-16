// Draws a live enemy with a sprite picked by kind; a defeated one simply
// stops drawing. All 3 kinds share the same red -- shape is what tells them apart.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("enemy.types.zig");

const WALKER_SPRITE = sprite_mod.fromArt(&.{
    "#..#..#.",
    ".######.",
    "##.##.##",
    "########",
    "########",
    ".######.",
    "#.#..#.#",
    "........",
});

// Splayed legs on both sides -- reads as gripping a wall regardless of
// which vertical direction it's currently patrolling.
const CREEPER_SPRITE = sprite_mod.fromArt(&.{
    "#.####.#",
    "##.##.##",
    ".######.",
    "########",
    ".######.",
    "##.##.##",
    "#.####.#",
    "#......#",
});

const FLY_SPRITE = sprite_mod.fromArt(&.{
    "........",
    "#.####.#",
    "##.##.##",
    "########",
    "########",
    "..#..#..",
    "........",
    "........",
});

pub fn draw(enemy: types.Enemy, offset_x: i32, offset_y: i32) void {
    if (!enemy.alive) return;
    w4.DRAW_COLORS.* = 0x0030; // color2 = palette[2] (red)
    const x: i32 = @as(i32, @intFromFloat(enemy.x)) + offset_x;
    const y: i32 = @as(i32, @intFromFloat(enemy.y)) + offset_y;
    const sprite = switch (enemy.kind) {
        .walker => &WALKER_SPRITE,
        .creeper => &CREEPER_SPRITE,
        .fly => &FLY_SPRITE,
    };
    sprite.draw(x, y, !enemy.facing_right);
}
