// Draws the player: rolling treads while gripping a surface, rise/peak/fall
// while airborne mid-leap, squash on landing, an arc while swinging.

const std = @import("std");
const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const curve = @import("../core/core.curve.zig");
const types = @import("character.types.zig");

// How finely the swirl's curve is subdivided -- higher reads smoother but
// costs more Oval draw calls per frame while swinging.
const SWIRL_SAMPLES: u32 = 14;

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

// The swirl's swept path: a short bulged blade segment, fixed width, whose
// center angle moves (swirlCenterAngle) so it orbits rather than sits fixed.
const SWIRL_RADIUS: f32 = 13;
const SWIRL_BULGE: f32 = 24;
const SWIRL_ARC_WIDTH: f32 = 2.2; // angular width of the visible blade, in radians
const SWIRL_BASE_ANGLE: f32 = -2.6; // where the orbit starts (0 = right, +y = down)
const SWIRL_TOTAL_ROTATION: f32 = 6.6; // a bit over one full turn over the whole swing

fn swirlCenterAngle(progress: f32) f32 {
    return SWIRL_BASE_ANGLE + progress * SWIRL_TOTAL_ROTATION;
}

fn swirlCurvePoint(center: curve.Point, center_angle: f32, t: f32) curve.Point {
    const a0 = center_angle - SWIRL_ARC_WIDTH / 2;
    const a1 = center_angle + SWIRL_ARC_WIDTH / 2;
    const p0 = curve.Point{ .x = center.x + @cos(a0) * SWIRL_RADIUS, .y = center.y + @sin(a0) * SWIRL_RADIUS };
    const p1 = curve.Point{ .x = center.x + @cos(center_angle) * SWIRL_BULGE, .y = center.y + @sin(center_angle) * SWIRL_BULGE };
    const p2 = curve.Point{ .x = center.x + @cos(a1) * SWIRL_RADIUS, .y = center.y + @sin(a1) * SWIRL_RADIUS };
    return curve.quadraticBezier(p0, p1, p2, t);
}

// 0 at both ends of the swing, peaking at its midpoint -- like a real smear
// frame, the blade grows fattest exactly where the swing is moving fastest.
const SWIRL_MIN_DIAM: f32 = 3;
const SWIRL_MAX_DIAM: f32 = 9;
fn swirlDiameter(t: f32) f32 {
    return SWIRL_MIN_DIAM + @sin(t * std.math.pi) * (SWIRL_MAX_DIAM - SWIRL_MIN_DIAM);
}

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

pub fn draw(char: types.Character) void {
    // Flicker every 8 frames while invulnerable, reading as "still recovering".
    if (char.invuln_timer > 0 and (char.invuln_timer / 4) % 2 == 0) return;
    // 1BPP '#' bits (core.sprite.fromArt) read DRAW_COLORS' color2 slot.
    w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3] (yellow)
    pickSprite(char).draw(@intFromFloat(char.x), @intFromFloat(char.y), !char.facing_right);

    if (char.swing_timer > 0) {
        const center = curve.Point{ .x = char.x + types.WIDTH / 2, .y = char.y + types.HEIGHT / 2 };
        const elapsed = types.SWING_FRAMES - char.swing_timer;
        const progress = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(types.SWING_FRAMES));
        const center_angle = swirlCenterAngle(progress);
        w4.DRAW_COLORS.* = 0x0002; // color1 = palette[1] (white) fill, color2 = transparent (no border)
        // center_angle advances with progress -- redrawn fresh each frame,
        // this reads as orbiting the player, not a fixed shape filling in.
        var i: u32 = 0;
        while (i <= SWIRL_SAMPLES) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(SWIRL_SAMPLES));
            const p = swirlCurvePoint(center, center_angle, t);
            const diam = swirlDiameter(t);
            const half = diam / 2;
            w4.Oval(@intFromFloat(p.x - half), @intFromFloat(p.y - half), @intFromFloat(diam), @intFromFloat(diam));
        }
    }
}
