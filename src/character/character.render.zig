// Draws the player character. SPRITE is the asset -- ASCII art (see
// core.sprite.fromArt), not an imported image, so the pixels here are exactly what's drawn.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("character.types.zig");

const SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    "##.##.##",
    "########",
    "..####..",
    ".#.##.#.",
    "#..##..#",
    "..#..#..",
});

pub fn draw(char: types.Character) void {
    // Flicker every 8 frames while invulnerable, reading as "still recovering".
    if (char.invuln_timer > 0 and (char.invuln_timer / 4) % 2 == 0) return;
    // 1BPP '#' bits (core.sprite.fromArt) read DRAW_COLORS' color2 slot.
    w4.DRAW_COLORS.* = 0x0020;
    SPRITE.draw(@intFromFloat(char.x), @intFromFloat(char.y), !char.facing_right);
}
