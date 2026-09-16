// Draws the player character. Each pose is its own ASCII-art sprite, picked
// from vertical speed/ground state -- squash on landing, rise/peak/fall in the air.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("character.types.zig");

// Airborne poses are picked by comparing vel_y against this -- inside the
// band reads as "hanging near the peak", outside as rising or falling.
const PEAK_BAND: f32 = 1.0;

const IDLE_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    "##.##.##",
    "########",
    "..####..",
    ".#.##.#.",
    "#..##..#",
    "..#..#..",
});

const SQUASH_SPRITE = sprite_mod.fromArt(&.{
    "........",
    "........",
    "........",
    "........",
    "########",
    "##.##.##",
    "########",
    "#.####.#",
});

const RISE_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    "##.##.##",
    "########",
    "..####..",
    "...##...",
    "..#..#..",
    "........",
});

const PEAK_SPRITE = sprite_mod.fromArt(&.{
    "........",
    "..####..",
    ".######.",
    "#.####.#",
    "########",
    "..####..",
    ".#....#.",
    "........",
});

const FALL_SPRITE = sprite_mod.fromArt(&.{
    "........",
    "..####..",
    ".######.",
    "##.##.##",
    "########",
    "#.####.#",
    ".#.##.#.",
    "#......#",
});

fn pickSprite(char: types.Character) *const sprite_mod.Sprite {
    if (char.squash_timer > 0) return &SQUASH_SPRITE;
    if (!char.on_ground) {
        if (char.vel_y < -PEAK_BAND) return &RISE_SPRITE;
        if (char.vel_y > PEAK_BAND) return &FALL_SPRITE;
        return &PEAK_SPRITE;
    }
    return &IDLE_SPRITE;
}

pub fn draw(char: types.Character) void {
    // Flicker every 8 frames while invulnerable, reading as "still recovering".
    if (char.invuln_timer > 0 and (char.invuln_timer / 4) % 2 == 0) return;
    // 1BPP '#' bits (core.sprite.fromArt) read DRAW_COLORS' color2 slot.
    w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3] (yellow)
    pickSprite(char).draw(@intFromFloat(char.x), @intFromFloat(char.y), !char.facing_right);
}
