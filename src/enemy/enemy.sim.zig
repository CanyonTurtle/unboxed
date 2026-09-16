// Per-kind movement (walker: ground, creeper: a wall, fly: open air with a
// bob) plus one shared "battle" rule: stomp from above defeats, side contact hits back.

const gravity = @import("../core/core.gravity.zig");
const collision = @import("../core/core.collision.zig");
const room_types = @import("../room/room.types.zig");
const types = @import("enemy.types.zig");

const WALK_SPEED: f32 = 0.6;
const CREEP_SPEED: f32 = 0.5;
const FLY_SPEED: f32 = 0.7;
const FLY_BOB_AMPLITUDE: f32 = 6;
const FLY_BOB_PERIOD: u16 = 90; // frames for one full bob cycle
pub const CONTACT_DAMAGE: i32 = 1;

pub const Event = union(enum) { none, hit_player: i32, defeated };

fn tileQuery() collision.TileQuery {
    return .{ .tile_size = room_types.TILE_SIZE, .isSolid = &room_types.isSolid };
}

fn updateWalker(self: *types.Enemy) void {
    self.vel_x = if (self.facing_right) WALK_SPEED else -WALK_SPEED;
    gravity.apply(&self.vel_y, self.on_ground);
    const result = collision.moveAndCollide(&self.x, &self.y, types.WIDTH, types.HEIGHT, &self.vel_x, &self.vel_y, tileQuery());
    self.on_ground = result.on_ground;
    if (result.hit_wall) self.facing_right = !self.facing_right;
}

// No tile collision needed -- its patrol range is chosen at spawn to
// already sit in open space next to a wall (see map.sim.spawnEnemy).
fn updateCreeper(self: *types.Enemy) void {
    if (self.y <= self.range_min) self.climbing_up = false;
    if (self.y >= self.range_max) self.climbing_up = true;
    self.vel_y = if (self.climbing_up) -CREEP_SPEED else CREEP_SPEED;
    self.y += self.vel_y;
}

fn updateFly(self: *types.Enemy) void {
    if (self.x <= self.range_min) self.facing_right = true;
    if (self.x >= self.range_max) self.facing_right = false;
    self.vel_x = if (self.facing_right) FLY_SPEED else -FLY_SPEED;
    self.x += self.vel_x;
    self.anim_timer = (self.anim_timer + 1) % FLY_BOB_PERIOD;
    const phase = @as(f32, @floatFromInt(self.anim_timer)) / @as(f32, @floatFromInt(FLY_BOB_PERIOD)) * 6.283185;
    self.y = self.base_y + @sin(phase) * FLY_BOB_AMPLITUDE;
}

pub fn update(self: *types.Enemy, player_box: collision.Rect, player_vel_y: f32) Event {
    if (!self.alive) return .none;

    switch (self.kind) {
        .walker => updateWalker(self),
        .creeper => updateCreeper(self),
        .fly => updateFly(self),
    }

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

test "walker patrols horizontally and turns around at a wall" {
    room_types.active = .{};
    room_types.active_open_sides = [_]bool{false} ** 4;
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground; // a floor to land on
    room_types.active.tiles[9][12] = .wall; // a wall standing on that floor, ahead of the enemy
    var enemy = types.Enemy{ .kind = .walker, .x = 40, .y = 42, .alive = true, .facing_right = true };
    const far_away = collision.Rect{ .x = 200, .y = 200, .w = 1, .h = 1 };
    var ever_turned = false;
    var i: u32 = 0;
    while (i < 150) : (i += 1) {
        _ = update(&enemy, far_away, 0);
        try testing.expect(enemy.x <= 12 * 5 - types.WIDTH);
        if (!enemy.facing_right) ever_turned = true;
    }
    try testing.expect(ever_turned);
}

test "creeper patrols vertically between its range and never leaves it" {
    room_types.active = .{};
    var enemy = types.Enemy{ .kind = .creeper, .x = 10, .y = 20, .alive = true, .range_min = 20, .range_max = 40 };
    const far_away = collision.Rect{ .x = 200, .y = 200, .w = 1, .h = 1 };
    var reached_bottom = false;
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        _ = update(&enemy, far_away, 0);
        try testing.expect(enemy.y >= enemy.range_min - 1 and enemy.y <= enemy.range_max + 1);
        if (enemy.y >= 39) reached_bottom = true;
    }
    try testing.expect(reached_bottom);
}

test "fly patrols horizontally and bobs vertically around base_y" {
    room_types.active = .{};
    var enemy = types.Enemy{ .kind = .fly, .x = 10, .y = 30, .base_y = 30, .alive = true, .range_min = 10, .range_max = 30, .facing_right = true };
    const far_away = collision.Rect{ .x = 200, .y = 200, .w = 1, .h = 1 };
    var min_y: f32 = 1000;
    var max_y: f32 = -1000;
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        _ = update(&enemy, far_away, 0);
        try testing.expect(enemy.x >= enemy.range_min - 1 and enemy.x <= enemy.range_max + 1);
        min_y = @min(min_y, enemy.y);
        max_y = @max(max_y, enemy.y);
    }
    try testing.expect(max_y - min_y > 1); // it actually bobbed, not a flat line
}

test "update is a no-op for a dead enemy" {
    var enemy = types.Enemy{ .alive = false, .x = 10, .y = 10 };
    const player_box = collision.Rect{ .x = 10, .y = 10, .w = 8, .h = 8 };
    try testing.expectEqual(Event.none, update(&enemy, player_box, 1));
    try testing.expectEqual(@as(f32, 10), enemy.x);
}

test "stomping from above defeats the enemy, regardless of kind" {
    room_types.active = .{};
    var enemy = types.Enemy{ .kind = .fly, .x = 20, .y = 20, .alive = true, .range_min = 20, .range_max = 20, .base_y = 20 };
    const player_above = collision.Rect{ .x = 20, .y = 14, .w = 8, .h = 8 };
    const event = update(&enemy, player_above, 2);
    try testing.expectEqual(Event.defeated, event);
    try testing.expect(!enemy.alive);
}

test "side contact hits the player instead of defeating the enemy" {
    room_types.active = .{};
    var enemy = types.Enemy{ .kind = .creeper, .x = 20, .y = 20, .alive = true, .range_min = 20, .range_max = 20 };
    const player_side = collision.Rect{ .x = 25, .y = 20, .w = 8, .h = 8 };
    const event = update(&enemy, player_side, 0);
    try testing.expectEqual(CONTACT_DAMAGE, event.hit_player);
    try testing.expect(enemy.alive);
}
