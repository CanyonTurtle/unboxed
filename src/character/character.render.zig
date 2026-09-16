// Draws the player character (squash on landing, rise/peak/fall in the
// air) and, while swinging, a curved arc of blocks sweeping around them.

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

// The swirl's swept path -- a quadratic Bezier bowed past the swirl's own
// radius, bellying outward into a wide blade. Angles: 0 = right, +y = down.
const SWIRL_RADIUS: f32 = 9;
const SWIRL_BULGE: f32 = 17;
const SWIRL_START_ANGLE: f32 = -2.4;
const SWIRL_SWEEP_ANGLE: f32 = 4.2;

fn swirlCurvePoint(center: curve.Point, t: f32) curve.Point {
    const end_angle = SWIRL_START_ANGLE + SWIRL_SWEEP_ANGLE;
    const mid_angle = (SWIRL_START_ANGLE + end_angle) / 2;
    const p0 = curve.Point{ .x = center.x + @cos(SWIRL_START_ANGLE) * SWIRL_RADIUS, .y = center.y + @sin(SWIRL_START_ANGLE) * SWIRL_RADIUS };
    const p1 = curve.Point{ .x = center.x + @cos(mid_angle) * SWIRL_BULGE, .y = center.y + @sin(mid_angle) * SWIRL_BULGE };
    const p2 = curve.Point{ .x = center.x + @cos(end_angle) * SWIRL_RADIUS, .y = center.y + @sin(end_angle) * SWIRL_RADIUS };
    return curve.quadraticBezier(p0, p1, p2, t);
}

// 0 at both ends of the swing, peaking at its midpoint -- like a real smear
// frame, the blade grows fattest exactly where the swing is moving fastest.
const SWIRL_MIN_DIAM: f32 = 2;
const SWIRL_MAX_DIAM: f32 = 7;
fn swirlDiameter(t: f32) f32 {
    return SWIRL_MIN_DIAM + @sin(t * std.math.pi) * (SWIRL_MAX_DIAM - SWIRL_MIN_DIAM);
}

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
        const center = curve.Point{ .x = char.x + types.WIDTH / 2, .y = char.y + types.HEIGHT / 2 };
        const elapsed = types.SWING_FRAMES - char.swing_timer;
        const progress = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(types.SWING_FRAMES));
        w4.DRAW_COLORS.* = 0x0002; // color1 = palette[1] (white) fill, color2 = transparent (no border)
        // Redraws the whole swept-so-far curve every frame, each sample
        // sized by its own t, so the trail keeps its "squash" belly shape.
        var i: u32 = 0;
        while (i <= SWIRL_SAMPLES) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(SWIRL_SAMPLES));
            if (t > progress) break;
            const p = swirlCurvePoint(center, t);
            const diam = swirlDiameter(t);
            const half = diam / 2;
            w4.Oval(@intFromFloat(p.x - half), @intFromFloat(p.y - half), @intFromFloat(diam), @intFromFloat(diam));
        }
    }
}
