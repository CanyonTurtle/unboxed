// Draws the player character (squash on landing, rise/peak/fall in the
// air) and, while swinging, a small spark orbiting them for the swirl attack.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("character.types.zig");

// Airborne poses are picked by comparing vel_y against this -- inside the
// band reads as "hanging near the peak", outside as rising or falling.
const PEAK_BAND: f32 = 1.0;

// Drawn as if facing right (mirrored when facing_right is false), with a
// forward arm/leg leading a trailing back one, so the silhouette itself reads facing.
const IDLE_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".#.##.#.",
    "..####..",
    ".#######",
    "..######",
    ".######.",
    "..####..",
    ".#....#.",
    "..#..##.",
    "..#...##",
});

const SQUASH_SPRITE = sprite_mod.fromArt(&.{
    "........",
    "........",
    "........",
    "........",
    "........",
    "........",
    "########",
    "##.##.##",
    "########",
    "########",
    "#.####.#",
});

const RISE_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".#.##.#.",
    "..####..",
    ".#######",
    "..######",
    ".######.",
    "..####..",
    "...##...",
    "..#...#.",
    "........",
});

const PEAK_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".#.##.#.",
    "..####..",
    ".#######",
    ".######.",
    "..####..",
    ".#....#.",
    "..#...#.",
    "........",
    "........",
});

const FALL_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".#.##.#.",
    "#.####.#",
    ".#######",
    "..######",
    ".######.",
    ".#....#.",
    "#......#",
    "#......#",
    "........",
});

// A small spark, repositioned around the character each frame it's drawn
// (see SWIRL_OFFSETS below) to read as a full spin rather than one slash.
const SWORD_SPRITE = sprite_mod.fromArt(&.{
    ".#.",
    "###",
    ".#.",
});

// One step per frame of swing_timer -- cycling through all 8 places the
// spark's radius as it counts down draws a full circle around the character.
const SWIRL_RADIUS: f32 = 9;
const SWIRL_OFFSETS = [8]struct { dx: f32, dy: f32 }{
    .{ .dx = 1, .dy = 0 },
    .{ .dx = 0.7, .dy = -0.7 },
    .{ .dx = 0, .dy = -1 },
    .{ .dx = -0.7, .dy = -0.7 },
    .{ .dx = -1, .dy = 0 },
    .{ .dx = -0.7, .dy = 0.7 },
    .{ .dx = 0, .dy = 1 },
    .{ .dx = 0.7, .dy = 0.7 },
};

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

    if (char.swing_timer > 0) {
        const center_x = char.x + types.WIDTH / 2;
        const center_y = char.y + types.HEIGHT / 2;
        const step = SWIRL_OFFSETS[char.swing_timer % SWIRL_OFFSETS.len];
        w4.DRAW_COLORS.* = 0x0020; // color2 = palette[1] (white) -- stands out from both bg and player
        SWORD_SPRITE.draw(
            @intFromFloat(center_x + step.dx * SWIRL_RADIUS - 1),
            @intFromFloat(center_y + step.dy * SWIRL_RADIUS - 1),
            false,
        );
    }
}
