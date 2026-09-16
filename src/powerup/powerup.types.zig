// A room-clear reward -- pure data; see powerup.sim.zig for the pickup
// rule and game.sim.zig for how each kind permanently changes the player.

const collision = @import("../core/core.collision.zig");

pub const SIZE: f32 = 8;

pub const PowerupKind = enum { extra_hp };

pub const Powerup = struct {
    x: f32 = 0,
    y: f32 = 0,
    kind: PowerupKind = .extra_hp,
    // False for a room with no powerup at all (the start room). True rooms
    // stay hidden (see `revealed`) until map.sim clears them for pickup.
    placed: bool = false,
    revealed: bool = false,
    collected: bool = false,

    pub fn aabb(self: Powerup) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = SIZE, .h = SIZE };
    }
};

// One powerup per room, like character.types.player -- map.sim swaps this
// out along with every other per-room entity array on a room transition.
pub var active: Powerup = .{};
