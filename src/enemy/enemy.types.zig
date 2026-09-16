// An enemy -- pure data; see enemy.sim.zig for movement/combat, which
// branches per `kind`, sharing one struct rather than three near-identical types.

const collision = @import("../core/core.collision.zig");

pub const WIDTH: f32 = 8;
pub const HEIGHT: f32 = 8;
pub const MAX_COUNT = 3;

pub const EnemyKind = enum { walker, creeper, fly };

pub const Enemy = struct {
    kind: EnemyKind = .walker,
    x: f32 = 0,
    y: f32 = 0,
    vel_x: f32 = 0,
    vel_y: f32 = 0,
    facing_right: bool = true, // also "moving right", for walker/fly
    climbing_up: bool = false, // creeper's own vertical direction
    on_ground: bool = false, // walker only
    alive: bool = false,
    anim_timer: u16 = 0, // wraps; drives fly's bob
    // creeper: top/bottom y bound. fly: left/right x bound, plus base_y it
    // bobs around. Unused by walker, which reverses off collisions instead.
    range_min: f32 = 0,
    range_max: f32 = 0,
    base_y: f32 = 0,

    pub fn aabb(self: Enemy) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = WIDTH, .h = HEIGHT };
    }
};

pub var enemies: [MAX_COUNT]Enemy = [_]Enemy{.{}} ** MAX_COUNT;
