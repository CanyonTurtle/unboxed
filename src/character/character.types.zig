// The player character's state -- pure data, no WASM4/room deps, so it's
// testable in isolation (see character.sim.zig's tests).

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 11;
pub const BASE_MAX_HP: i32 = 5;

// The sword's reach while swinging -- a box extending out from whichever
// side the character faces, well past their own silhouette.
const SWING_REACH: f32 = 9;
const SWING_HEIGHT: f32 = 7;

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
    // Nonzero while a midair sword swing is active -- see swingHitbox
    // below; ordinary jump-on-top still works whether or not this is set.
    swing_timer: u8 = 0,

    pub fn aabb(self: Character) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }

    // The sword's own hitbox this frame, or null while not swinging.
    pub fn swingHitbox(self: Character) ?collision.Rect {
        if (self.swing_timer == 0) return null;
        const mid_y = self.y + HEIGHT / 2 - SWING_HEIGHT / 2;
        return if (self.facing_right)
            .{ .x = self.x + WIDTH, .y = mid_y, .w = SWING_REACH, .h = SWING_HEIGHT }
        else
            .{ .x = self.x - SWING_REACH, .y = mid_y, .w = SWING_REACH, .h = SWING_HEIGHT };
    }
};

pub var player: Character = .{};

const testing = @import("std").testing;

test "swingHitbox is null while not swinging" {
    const c = Character{ .swing_timer = 0 };
    try testing.expect(c.swingHitbox() == null);
}

test "swingHitbox extends in front of the character, facing-dependent" {
    const right_facing = Character{ .x = 10, .y = 10, .swing_timer = 3, .facing_right = true };
    const right_box = right_facing.swingHitbox().?;
    try testing.expectEqual(@as(f32, 10 + WIDTH), right_box.x);

    const left_facing = Character{ .x = 10, .y = 10, .swing_timer = 3, .facing_right = false };
    const left_box = left_facing.swingHitbox().?;
    try testing.expectEqual(@as(f32, 10 - SWING_REACH), left_box.x);
}
