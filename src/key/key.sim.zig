// A key is collected the instant the player touches it. Mirrors
// powerup.sim.update's shape -- see that file's comment.

const collision = @import("../core/core.collision.zig");
const types = @import("key.types.zig");

pub const Event = union(enum) { none, collected };

pub fn update(self: *types.Key, player_box: collision.Rect) Event {
    if (!self.placed or self.collected) return .none;
    if (!self.aabb().overlaps(player_box)) return .none;
    self.collected = true;
    return .collected;
}

const testing = @import("std").testing;

test "update collects a placed key on player contact" {
    var k = types.Key{ .x = 10, .y = 10, .placed = true };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.collected, update(&k, player_box));
    try testing.expect(k.collected);
}

test "update ignores a room with no key placed" {
    var k = types.Key{ .x = 10, .y = 10, .placed = false };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&k, player_box));
}

test "update ignores contact once already collected" {
    var k = types.Key{ .x = 10, .y = 10, .placed = true, .collected = true };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&k, player_box));
}
