// A patrolling enemy -- pure data; see enemy.sim.zig for movement/combat.

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 8;
pub const MAX_COUNT = 3;

pub const Enemy = struct {
    x: f32 = 0,
    y: f32 = 0,
    vel_x: f32 = 0,
    vel_y: f32 = 0,
    facing_right: bool = true,
    on_ground: bool = false,
    alive: bool = false,

    pub fn aabb(self: Enemy) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }
};

pub var enemies: [MAX_COUNT]Enemy = [_]Enemy{.{}} ** MAX_COUNT;
