// An item is collected the instant the player touches it. Returns which
// kind, so game.sim can apply its effect without this module knowing about score/hp.

const collision = @import("../core/core.collision.zig");
const types = @import("item.types.zig");

pub const Event = union(enum) { none, collected: types.ItemKind };

pub fn update(self: *types.Item, player_box: collision.Rect) Event {
    if (self.collected) return .none;
    if (!self.aabb().overlaps(player_box)) return .none;
    self.collected = true;
    return .{ .collected = self.kind };
}

const testing = @import("std").testing;

test "update collects an item on player contact and reports its kind" {
    var item = types.Item{ .x = 10, .y = 10, .kind = .heart, .collected = false };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    const event = update(&item, player_box);
    try testing.expectEqual(types.ItemKind.heart, event.collected);
    try testing.expect(item.collected);
}

test "update ignores an already-collected item" {
    var item = types.Item{ .x = 10, .y = 10, .collected = true };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&item, player_box));
}
