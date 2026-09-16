// A pot breaks the instant the player touches it. No physics of its own --
// it just sits and waits for contact, unlike character/enemy which move.

const collision = @import("../core/core.collision.zig");
const types = @import("pot.types.zig");

pub const Event = enum { none, broke };

// Returns `.broke` exactly once, on the frame contact happens, so callers
// can react without polling `broken` every frame.
pub fn update(self: *types.Pot, player_box: collision.Rect) Event {
    if (self.broken) return .none;
    if (!self.aabb().overlaps(player_box)) return .none;
    self.broken = true;
    return .broke;
}

const testing = @import("std").testing;

test "update breaks a pot on player contact and reports it exactly once" {
    var pot = types.Pot{ .x = 10, .y = 10 };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.broke, update(&pot, player_box));
    try testing.expect(pot.broken);
    try testing.expectEqual(Event.none, update(&pot, player_box));
}

test "update leaves an untouched pot alone" {
    var pot = types.Pot{ .x = 0, .y = 0 };
    const far_away = collision.Rect{ .x = 100, .y = 100, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&pot, far_away));
    try testing.expect(!pot.broken);
}
