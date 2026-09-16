// The player character's state -- pure data, no WASM4/room deps, so it's
// testable in isolation (see character.sim.zig's tests).

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 8;
pub const BASE_MAX_HP: i32 = 5;

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

    pub fn aabb(self: Character) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }
};

pub var player: Character = .{};
