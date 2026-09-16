// Draws the player character (squash on landing, rise/peak/fall in the
// air) and, while swinging, a curved arc of blocks sweeping around them.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("character.types.zig");

// Airborne poses are picked by comparing vel_y against this -- inside the
// band reads as "hanging near the peak", outside as rising or falling.
const PEAK_BAND: f32 = 1.0;

// Drawn as if facing right (mirrored -- draw()'s flip_x -- when facing
// left): a single eye toward the front, plus a forward arm/leg leading a trailing back one.
const IDLE_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".####.#.",
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
    ".####.#.",
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
    ".####.#.",
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
    ".####.#.",
    "#.####.#",
    ".#######",
    "..######",
    ".######.",
    ".#....#.",
    "#......#",
    "#......#",
    "........",
});

// One filled block of the arc trail -- several are drawn per frame (see
// SWIRL_ARC_LEN below) so the swing reads as a swept curve, not one dot.
const SWORD_SPRITE = sprite_mod.fromArt(&.{
    "##",
    "##",
});

// 12 points around the circle; each frame draws SWIRL_ARC_LEN consecutive
// ones as a crescent, whose start rotates with swing_timer -- so the crescent itself sweeps.
const SWIRL_STEPS = 12;
const SWIRL_ARC_LEN = 5;
const SWIRL_RADIUS: f32 = 9;
const SWIRL_OFFSETS = [SWIRL_STEPS]struct { dx: f32, dy: f32 }{
    .{ .dx = 1.0, .dy = 0.0 },
    .{ .dx = 0.87, .dy = -0.5 },
    .{ .dx = 0.5, .dy = -0.87 },
    .{ .dx = 0.0, .dy = -1.0 },
    .{ .dx = -0.5, .dy = -0.87 },
    .{ .dx = -0.87, .dy = -0.5 },
    .{ .dx = -1.0, .dy = 0.0 },
    .{ .dx = -0.87, .dy = 0.5 },
    .{ .dx = -0.5, .dy = 0.87 },
    .{ .dx = 0.0, .dy = 1.0 },
    .{ .dx = 0.5, .dy = 0.87 },
    .{ .dx = 0.87, .dy = 0.5 },
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
        const head: usize = char.swing_timer % SWIRL_STEPS;
        w4.DRAW_COLORS.* = 0x0020; // color2 = palette[1] (white) -- stands out from both bg and player
        var i: usize = 0;
        while (i < SWIRL_ARC_LEN) : (i += 1) {
            const step = SWIRL_OFFSETS[(head + i) % SWIRL_STEPS];
            SWORD_SPRITE.draw(
                @intFromFloat(center_x + step.dx * SWIRL_RADIUS - 1),
                @intFromFloat(center_y + step.dy * SWIRL_RADIUS - 1),
                false,
            );
        }
    }
}
