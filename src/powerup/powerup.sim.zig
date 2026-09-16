// A powerup is collected the instant the player touches it, once revealed.
// Mirrors item.sim.update's shape exactly -- see that file's comment.

const collision = @import("../core/core.collision.zig");
const types = @import("powerup.types.zig");

pub const Event = union(enum) { none, collected: types.PowerupKind };

pub fn update(self: *types.Powerup, player_box: collision.Rect) Event {
    if (!self.placed or !self.revealed or self.collected) return .none;
    if (!self.aabb().overlaps(player_box)) return .none;
    self.collected = true;
    return .{ .collected = self.kind };
}

const testing = @import("std").testing;

test "update collects a revealed powerup on player contact" {
    var p = types.Powerup{ .x = 10, .y = 10, .kind = .double_jump, .placed = true, .revealed = true };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    const event = update(&p, player_box);
    try testing.expectEqual(types.PowerupKind.double_jump, event.collected);
    try testing.expect(p.collected);
}

test "update ignores a powerup that hasn't been revealed yet" {
    var p = types.Powerup{ .x = 10, .y = 10, .placed = true, .revealed = false };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&p, player_box));
}

test "update ignores a room with no powerup placed" {
    var p = types.Powerup{ .x = 10, .y = 10, .placed = false, .revealed = true };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&p, player_box));
}
