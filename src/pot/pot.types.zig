// A breakable pot -- pure data; see pot.sim.zig for the break rule.

const collision = @import("../core/core.collision.zig");

pub const SIZE: f32 = 8;
pub const MAX_COUNT = 4;

pub const Pot = struct {
    x: f32 = 0,
    y: f32 = 0,
    broken: bool = false,

    pub fn aabb(self: Pot) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = SIZE, .h = SIZE };
    }
};

pub var pots: [MAX_COUNT]Pot = [_]Pot{.{}} ** MAX_COUNT;
