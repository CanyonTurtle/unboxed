// A room's objective -- pure data; see key.sim.zig for the pickup rule and
// map.sim.isRoomCleared for how collecting it opens every valid door.

const collision = @import("../core/core.collision.zig");

pub const SIZE: f32 = 8;

pub const Key = struct {
    x: f32 = 0,
    y: f32 = 0,
    // False for a room with no key at all (the start room, already open).
    placed: bool = false,
    collected: bool = false,

    pub fn aabb(self: Key) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = SIZE, .h = SIZE };
    }
};

// One key per room, like powerup.types.active -- map.sim swaps this out
// along with every other per-room entity on a room transition.
pub var active: Key = .{};
