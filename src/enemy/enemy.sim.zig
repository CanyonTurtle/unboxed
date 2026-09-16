// Enemy patrol (gravity + tile collision, like character.sim) plus this
// game's whole "battle" rule: stomp from above to defeat, side contact hits back.

const gravity = @import("../core/core.gravity.zig");
const collision = @import("../core/core.collision.zig");
const room_types = @import("../room/room.types.zig");
const types = @import("enemy.types.zig");

const PATROL_SPEED: f32 = 0.6;
pub const CONTACT_DAMAGE: i32 = 1;

pub const Event = union(enum) { none, hit_player: i32, defeated };

pub fn update(self: *types.Enemy, player_box: collision.Rect, player_vel_y: f32) Event {
    if (!self.alive) return .none;

    self.vel_x = if (self.facing_right) PATROL_SPEED else -PATROL_SPEED;
    gravity.apply(&self.vel_y, self.on_ground);

    const tiles = collision.TileQuery{ .tile_size = room_types.TILE_SIZE, .isSolid = &room_types.isSolid };
    const result = collision.moveAndCollide(&self.x, &self.y, types.WIDTH, types.HEIGHT, &self.vel_x, &self.vel_y, tiles);
    self.on_ground = result.on_ground;
    if (result.hit_wall) self.facing_right = !self.facing_right; // turn around at a wall

    if (!self.aabb().overlaps(player_box)) return .none;

    // Stomped: falling, and mostly above the enemy's own top edge -- a
    // simple stand-in for real per-side contact resolution.
    const stomped = player_vel_y > 0 and player_box.y < self.y;
    if (stomped) {
        self.alive = false;
        return .defeated;
    }
    return .{ .hit_player = CONTACT_DAMAGE };
}

const testing = @import("std").testing;

test "update patrols horizontally and turns around at a wall" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[6][tx] = .ground; // a floor to land on
    room_types.active.tiles[5][8] = .wall; // a wall standing on that floor, ahead of the enemy
    var enemy = types.Enemy{ .x = 40, .y = 32, .alive = true, .facing_right = true };
    const far_away = collision.Rect{ .x = 200, .y = 200, .w = 1, .h = 1 };
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = update(&enemy, far_away, 0);
        // Never tunnels past the wall, no matter when it lands and reaches it.
        try testing.expect(enemy.x <= 8 * 8);
    }
    // And it did in fact turn back after meeting the wall.
    try testing.expect(!enemy.facing_right);
}

test "update is a no-op for a dead enemy" {
    var enemy = types.Enemy{ .alive = false, .x = 10, .y = 10 };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&enemy, player_box, 1));
    try testing.expectEqual(@as(f32, 10), enemy.x);
}

test "stomping from above defeats the enemy" {
    room_types.active = .{};
    var enemy = types.Enemy{ .x = 20, .y = 20, .alive = true };
    // update() moves the enemy before checking contact, so this needs
    // margin to still overlap after that small same-frame nudge.
    const player_above = collision.Rect{ .x = 20, .y = 16, .w = 8, .h = 8 };
    const event = update(&enemy, player_above, 2);
    try testing.expectEqual(Event.defeated, event);
    try testing.expect(!enemy.alive);
}

test "side contact hits the player instead of defeating the enemy" {
    room_types.active = .{};
    var enemy = types.Enemy{ .x = 20, .y = 20, .alive = true };
    const player_side = collision.Rect{ .x = 25, .y = 20, .w = 8, .h = 8 };
    const event = update(&enemy, player_side, 0);
    try testing.expectEqual(CONTACT_DAMAGE, event.hit_player);
    try testing.expect(enemy.alive);
}
