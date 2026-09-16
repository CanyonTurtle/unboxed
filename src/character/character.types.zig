// The player character's state -- pure data, no WASM4/room deps, so it's
// testable in isolation (see character.sim.zig's tests).

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 8;
pub const MAX_HP: i32 = 5;

pub const Character = struct {
    x: f32 = 0,
    y: f32 = 0,
    vel_x: f32 = 0,
    vel_y: f32 = 0,
    facing_right: bool = true,
    on_ground: bool = false,
    hp: i32 = MAX_HP,
    // Brief flicker-and-ignore-damage window after a hit (character.sim.
    // takeDamage), so one contact can't drain the whole bar in one frame.
    invuln_timer: u16 = 0,
    score: u32 = 0,

    pub fn aabb(self: Character) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }
};

pub var player: Character = .{};
