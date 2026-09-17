// Draws the player: rolling treads while gripping a surface, rise/peak/fall
// while floating (no gravity, so these just read as "which way it's headed"), squash on landing.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("character.types.zig");

// Airborne poses are picked by comparing vel_y against this -- inside the
// band reads as "hanging near the peak", outside as rising or falling.
const PEAK_BAND: f32 = 1.0;

// Drawn facing right (mirrored when facing left): a single eye toward the
// front, atop a tread band. Two frames, hash-offset, alternate via drive_anim.
const TREAD_A = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".####.#.",
    "..####..",
    ".#######",
    "..######",
    ".######.",
    "..####..",
    "########",
    "#.#.#.#.",
    "########",
});

const TREAD_B = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    ".####.#.",
    "..####..",
    ".#######",
    "..######",
    ".######.",
    "..####..",
    "########",
    ".#.#.#.#",
    "########",
});

// Rotated 90 degrees for wall-climbing: tread against the gripped wall,
// body facing "up" the canvas -- flip_y turns it to face down instead.
const LEFT_WALL_TREAD_A = sprite_mod.fromArt(&.{
    "###..####..",
    "#.#.######.",
    "###.####.#.",
    "#.#..####..",
    "###.######.",
    "#.#.######.",
    "###..####..",
    "#.#########",
});

const LEFT_WALL_TREAD_B = sprite_mod.fromArt(&.{
    "#.#..####..",
    "###.######.",
    "#.#.####.#.",
    "###..####..",
    "#.#.######.",
    "###.######.",
    "#.#..####..",
    "###########",
});

const RIGHT_WALL_TREAD_A = sprite_mod.fromArt(&.{
    "..####..###",
    ".######.#.#",
    ".#.####.###",
    "..####..#.#",
    ".######.###",
    ".######.#.#",
    "..####..###",
    "#########.#",
});

const RIGHT_WALL_TREAD_B = sprite_mod.fromArt(&.{
    "..####..#.#",
    ".######.###",
    ".#.####.#.#",
    "..####..###",
    ".######.#.#",
    ".######.###",
    "..####..#.#",
    "###########",
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

// How many frames each tread pose holds before alternating to the other --
// slower reads as "rolling", not flickering.
const TREAD_ALTERNATE_FRAMES: u16 = 6;

fn pickSprite(char: types.Character) *const sprite_mod.Sprite {
    if (char.squash_timer > 0) return &SQUASH_SPRITE;
    if (char.surface == null) {
        if (char.vel_y < -PEAK_BAND) return &RISE_SPRITE;
        if (char.vel_y > PEAK_BAND) return &FALL_SPRITE;
        return &PEAK_SPRITE;
    }
    return if ((char.drive_anim / TREAD_ALTERNATE_FRAMES) % 2 == 0) &TREAD_A else &TREAD_B;
}

// The rotated wall sprites are 11x8, not the usual 8x11 -- centered on the
// same point as the upright hitbox so they don't look shifted against it.
fn drawWallClimb(char: types.Character) void {
    const frame = (char.drive_anim / TREAD_ALTERNATE_FRAMES) % 2;
    const sprite = switch (char.surface.?) {
        .left_wall => if (frame == 0) &LEFT_WALL_TREAD_A else &LEFT_WALL_TREAD_B,
        else => if (frame == 0) &RIGHT_WALL_TREAD_A else &RIGHT_WALL_TREAD_B,
    };
    const draw_x = char.x + types.WIDTH / 2 - 5.5;
    const draw_y = char.y + types.HEIGHT / 2 - 4.0;
    sprite.drawFlipped(@intFromFloat(draw_x), @intFromFloat(draw_y), false, char.vel_y > 0);
}

pub fn draw(char: types.Character) void {
    // Flicker every 8 frames while invulnerable, reading as "still recovering".
    if (char.invuln_timer > 0 and (char.invuln_timer / 4) % 2 == 0) return;
    // 1BPP '#' bits (core.sprite.fromArt) read DRAW_COLORS' color2 slot.
    w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3] (yellow)
    if (char.squash_timer == 0 and (char.surface == .left_wall or char.surface == .right_wall)) {
        drawWallClimb(char);
    } else {
        pickSprite(char).draw(@intFromFloat(char.x), @intFromFloat(char.y), !char.facing_right);
    }
}
