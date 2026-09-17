// The player character's state -- pure data, no WASM4/room deps, so it's
// testable in isolation (see character.sim.zig's tests).

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 11;
pub const BASE_MAX_HP: i32 = 5;

// Which of the room's 4 inner surfaces the tank grips -- null means airborne.
// See character.sim.update for the per-surface travel/grip axis mapping.
pub const Surface = enum { floor, ceiling, left_wall, right_wall };

pub const Character = struct {
    x: f32 = 0,
    y: f32 = 0,
    vel_x: f32 = 0,
    vel_y: f32 = 0,
    facing_right: bool = true,
    surface: ?Surface = null,
    // Rotational sense the tank drives in (true = clockwise) -- see `speed`.
    clockwise: bool = false,
    // Drive speed, 0..MAX_SPEED -- builds while a direction is held, bleeds
    // off when it isn't. Releasing fires a leap+swirl scaled by it, then resets to 0.
    speed: f32 = 0,
    // Wraps continuously while gripping a surface -- character.render uses
    // it to alternate tread frames, giving the tracks a rolling look.
    drive_anim: u16 = 0,
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
    // Nonzero for a few frames right after landing -- character.render
    // shows a squashed pose while it counts down (character.sim.update).
    squash_timer: u8 = 0,

    pub fn aabb(self: Character) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }
};

pub var player: Character = .{};
