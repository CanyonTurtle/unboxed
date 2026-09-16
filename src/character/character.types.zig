// The player character's state -- pure data, no WASM4/room deps, so it's
// testable in isolation (see character.sim.zig's tests).

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 11;
pub const BASE_MAX_HP: i32 = 5;

// How far the midair swirl attack reaches on every side of the character --
// it's an all-around spin, not a directional poke, so it isn't facing-dependent.
const SWING_RADIUS: f32 = 8;
// How long a swirl attack lasts, in frames -- shared with character.render
// (the swept-arc animation) so the two can't drift out of sync.
pub const SWING_FRAMES: u8 = 10;

pub const Character = struct {
    x: f32 = 0,
    y: f32 = 0,
    vel_x: f32 = 0,
    vel_y: f32 = 0,
    facing_right: bool = true,
    on_ground: bool = false,
    hp: i32 = BASE_MAX_HP,
    // Raised permanently by an extra_hp powerup (powerup.sim) -- BASE_MAX_HP
    // is only the run's starting cap.
    max_hp: i32 = BASE_MAX_HP,
    // Brief flicker-and-ignore-damage window after a hit (character.sim.
    // takeDamage), so one contact can't drain the whole bar in one frame.
    invuln_timer: u16 = 0,
    // Nonzero right after a hit -- suppresses input (character.sim.update)
    // so knockback plays out before control returns.
    hit_stun_timer: u16 = 0,
    score: u32 = 0,
    // Unlocked permanently by a double_jump powerup; air_jumps_used resets
    // to 0 the instant on_ground goes true (character.sim.update).
    has_double_jump: bool = false,
    air_jumps_used: u8 = 0,
    // Which side a wall is on while airborne and pressing into it (-1 left,
    // 0 none, 1 right) -- drives wall-slide and wall-jump (character.sim).
    wall_side: i8 = 0,
    // Nonzero for a few frames right after landing -- character.render
    // shows a squashed pose while it counts down (character.sim.update).
    squash_timer: u8 = 0,
    // Nonzero while a midair swirl attack is active -- see swingHitbox
    // below. It's the only way to defeat an enemy now; jumping on one just bounces off.
    swing_timer: u8 = 0,

    pub fn aabb(self: Character) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }

    // The swirl's hitbox this frame, or null while not swinging -- a ring
    // around the whole character, since a spin attack hits every side at once.
    pub fn swingHitbox(self: Character) ?collision.Rect {
        if (self.swing_timer == 0) return null;
        return .{
            .x = self.x - SWING_RADIUS,
            .y = self.y - SWING_RADIUS,
            .w = WIDTH + SWING_RADIUS * 2,
            .h = HEIGHT + SWING_RADIUS * 2,
        };
    }
};

pub var player: Character = .{};

const testing = @import("std").testing;

test "swingHitbox is null while not swinging" {
    const c = Character{ .swing_timer = 0 };
    try testing.expect(c.swingHitbox() == null);
}

test "swingHitbox surrounds the character on every side, regardless of facing" {
    const c = Character{ .x = 10, .y = 10, .swing_timer = 3, .facing_right = false };
    const box = c.swingHitbox().?;
    try testing.expectEqual(@as(f32, 10 - SWING_RADIUS), box.x);
    try testing.expectEqual(@as(f32, 10 - SWING_RADIUS), box.y);
    try testing.expectEqual(WIDTH + SWING_RADIUS * 2, box.w);
    try testing.expectEqual(HEIGHT + SWING_RADIUS * 2, box.h);
}
