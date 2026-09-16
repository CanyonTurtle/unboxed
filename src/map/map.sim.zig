// Room generation and forward-only transitions -- the one file that knows
// both the room progression and the per-room entity arrays it copies around.

const rng_mod = @import("../core/core.rng.zig");
const camera = @import("../core/core.camera.zig");
const room_types = @import("../room/room.types.zig");
const room_sim = @import("../room/room.sim.zig");
const pot_types = @import("../pot/pot.types.zig");
const item_types = @import("../item/item.types.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const powerup_types = @import("../powerup/powerup.types.zig");
const particle_sim = @import("../particle/particle.sim.zig");
const char_types = @import("../character/character.types.zig");
const map_types = @import("map.types.zig");

const SEED_BASE: u32 = 0xc0ffee;
const ROOM_SIZE: f32 = @as(f32, @floatFromInt(room_types.GRID_W)) * room_types.TILE_SIZE;

fn seedFor(index: u32) u32 {
    return SEED_BASE +% index *% 2654435761;
}

fn tilePx(t: u32) f32 {
    return @as(f32, @floatFromInt(t)) * room_types.TILE_SIZE;
}

// Fills in a fresh room -- enemy count and powerup tier scale with `index`,
// the only "how deep is this run" signal now that rooms form a line.
fn generateInto(save: *map_types.RoomSave, index: u32, is_start: bool) void {
    var rng = rng_mod.Rng{ .state = seedFor(index) };
    room_sim.generate(&save.room, &rng);

    for (&save.pots) |*pot| {
        const spot = room_sim.randomFloorSpot(&save.room, &rng);
        pot.* = .{ .x = tilePx(spot.tx), .y = tilePx(spot.ty) };
    }
    for (&save.items) |*item| item.* = .{};

    const enemy_count: usize = if (is_start) 0 else 1 + @min(index, enemy_types.MAX_COUNT - 1);
    for (&save.enemies, 0..) |*enemy, i| {
        if (i < enemy_count) {
            const kind: enemy_types.EnemyKind = switch (rng.range(3)) {
                0 => .walker,
                1 => .creeper,
                else => .fly,
            };
            spawnEnemy(enemy, kind, &save.room, &rng);
        } else {
            enemy.* = .{};
        }
    }

    if (is_start) {
        save.powerup = .{};
    } else {
        const spot = room_sim.randomFloorSpot(&save.room, &rng);
        save.powerup = .{
            .x = tilePx(spot.tx),
            .y = tilePx(spot.ty),
            .placed = true,
        };
    }
}

// Placement is kind-specific (ground, wall range, or open-air range) --
// only walker's goes through randomFloorSpot.
fn spawnEnemy(enemy: *enemy_types.Enemy, kind: enemy_types.EnemyKind, room: *const room_types.Room, rng: *rng_mod.Rng) void {
    switch (kind) {
        .walker => {
            const spot = room_sim.randomFloorSpot(room, rng);
            enemy.* = .{ .kind = .walker, .x = tilePx(spot.tx), .y = tilePx(spot.ty), .alive = true };
        },
        .creeper => {
            const on_left = rng.range(2) == 0;
            const x = if (on_left) tilePx(2) else tilePx(room_types.GRID_W - 3);
            const top = tilePx(4);
            const bottom = tilePx(room_types.FLOOR_ROW - 4);
            enemy.* = .{ .kind = .creeper, .x = x, .y = top, .range_min = top, .range_max = bottom, .alive = true };
        },
        .fly => {
            const left = tilePx(4);
            const right = tilePx(room_types.GRID_W - 6);
            const y = tilePx(rng.between(8, 18));
            enemy.* = .{ .kind = .fly, .x = left, .y = y, .base_y = y, .range_min = left, .range_max = right, .facing_right = true, .alive = true };
        },
    }
}

fn doorSidesFor(entered: ?room_types.Side) [4]bool {
    var result = [_]bool{false} ** 4;
    for (map_types.DOOR_SIDES) |side| {
        if (map_types.isValidDoor(side, entered)) result[@intFromEnum(side)] = true;
    }
    return result;
}

fn loadActive() void {
    room_types.active = map_types.current.room;
    pot_types.pots = map_types.current.pots;
    item_types.items = map_types.current.items;
    enemy_types.enemies = map_types.current.enemies;
    powerup_types.active = map_types.current.powerup;
    room_types.active_door_sides = doorSidesFor(map_types.entered_from);
    room_types.active_open_sides = [_]bool{false} ** 4;
}

pub fn newRun() void {
    map_types.room_index = 0;
    map_types.entered_from = null;
    map_types.transition = .{};
    generateInto(&map_types.current, 0, true);
    loadActive();
}

pub fn isRoomCleared() bool {
    for (enemy_types.enemies) |e| {
        if (e.alive) return false;
    }
    return true;
}

fn revealPowerupOnceCleared() void {
    if (powerup_types.active.placed and !powerup_types.active.revealed and isRoomCleared()) {
        powerup_types.active.revealed = true;
    }
}

// Once cleared, every valid door opens at once -- no charge-up, just walk through.
fn updateDoors() void {
    if (!isRoomCleared()) return;
    for (0..4) |i| {
        if (room_types.active_door_sides[i]) room_types.active_open_sides[i] = true;
    }
}

// Entirely clear of the border tile -- landing even partly inside it starts
// the character embedded in solid geometry, which collision can't recover from.
fn entryPosition(entered: room_types.Side) struct { x: f32, y: f32 } {
    const floor_y = tilePx(room_types.FLOOR_ROW) - char_types.HEIGHT;
    return switch (entered) {
        .left => .{ .x = room_types.TILE_SIZE, .y = floor_y },
        .right => .{ .x = ROOM_SIZE - room_types.TILE_SIZE - char_types.WIDTH, .y = floor_y },
        .up => .{ .x = ROOM_SIZE / 2 - char_types.WIDTH / 2, .y = room_types.TILE_SIZE },
        .down => unreachable, // never a break source, so never an entry side
    };
}

fn startTransition(dir: room_types.Side, player: *const char_types.Character) void {
    generateInto(&map_types.next, map_types.room_index + 1, false);
    const end = entryPosition(map_types.opposite(dir));
    map_types.transition = .{
        .active = true,
        .dir = dir,
        .frame = 0,
        .start_x = player.x,
        .start_y = player.y,
        .end_x = end.x,
        .end_y = end.y,
    };
}

fn finishTransition(player: *char_types.Character) void {
    const t = map_types.transition;
    map_types.current = map_types.next;
    map_types.entered_from = map_types.opposite(t.dir);
    map_types.room_index += 1;
    loadActive();
    particle_sim.clear();
    player.x = t.end_x;
    player.y = t.end_y;
    player.vel_x = 0;
    player.vel_y = 0;
    player.on_ground = false;
    map_types.transition = .{};
}

// Slides the player from where the transition began to where they'll stand
// in the next room, in lockstep with the same easing the camera uses.
fn advanceTransition(player: *char_types.Character) void {
    const t = &map_types.transition;
    t.frame += 1;
    const progress = @min(1.0, @as(f32, @floatFromInt(t.frame)) / @as(f32, @floatFromInt(map_types.TRANSITION_FRAMES)));
    const eased = camera.easeOutQuad(progress);
    player.x = t.start_x + (t.end_x - t.start_x) * eased;
    player.y = t.start_y + (t.end_y - t.start_y) * eased;
    if (t.frame >= map_types.TRANSITION_FRAMES) finishTransition(player);
}

fn maybeStartTransition(player: *const char_types.Character) void {
    if (player.x <= 0 and room_types.active_open_sides[@intFromEnum(room_types.Side.left)]) {
        startTransition(.left, player);
    } else if (player.x + char_types.WIDTH >= ROOM_SIZE and room_types.active_open_sides[@intFromEnum(room_types.Side.right)]) {
        startTransition(.right, player);
    } else if (player.y + char_types.HEIGHT >= ROOM_SIZE and room_types.active_open_sides[@intFromEnum(room_types.Side.down)]) {
        startTransition(.down, player);
    }
}

pub fn update(player: *char_types.Character) void {
    if (map_types.transition.active) {
        advanceTransition(player);
        return;
    }
    revealPowerupOnceCleared();
    updateDoors();
    maybeStartTransition(player);
}

const testing = @import("std").testing;

test "newRun starts a cleared room (no enemies) with all 3 doors valid" {
    newRun();
    try testing.expect(isRoomCleared());
    try testing.expect(room_types.active_door_sides[@intFromEnum(room_types.Side.left)]);
    try testing.expect(room_types.active_door_sides[@intFromEnum(room_types.Side.right)]);
    try testing.expect(room_types.active_door_sides[@intFromEnum(room_types.Side.down)]);
    try testing.expect(!room_types.active_door_sides[@intFromEnum(room_types.Side.up)]);
}

test "a generated non-start room has at least one enemy and a placed powerup" {
    var save: map_types.RoomSave = .{};
    generateInto(&save, 1, false);
    var alive_count: u32 = 0;
    for (save.enemies) |e| {
        if (e.alive) alive_count += 1;
    }
    try testing.expect(alive_count >= 1);
    try testing.expect(save.powerup.placed);
}

test "doors only open once the room is cleared" {
    newRun();
    enemy_types.enemies[0] = .{ .alive = true, .x = 5, .y = 5 };
    var player = char_types.Character{};
    update(&player);
    try testing.expect(!room_types.active_open_sides[@intFromEnum(room_types.Side.right)]);

    enemy_types.enemies[0].alive = false;
    update(&player);
    try testing.expect(room_types.active_open_sides[@intFromEnum(room_types.Side.right)]);
}

test "walking into an open door starts a transition" {
    newRun();
    var player = char_types.Character{ .x = ROOM_SIZE - char_types.WIDTH, .y = tilePx(room_types.FLOOR_ROW) - char_types.HEIGHT };
    update(&player); // room already cleared -> this opens every door
    update(&player); // touching the right edge -> starts the transition

    try testing.expect(map_types.transition.active);
    try testing.expectEqual(room_types.Side.right, map_types.transition.dir);
}

test "a completed transition enters the next room from the opposite side" {
    newRun();
    var player = char_types.Character{ .x = ROOM_SIZE - char_types.WIDTH, .y = tilePx(room_types.FLOOR_ROW) - char_types.HEIGHT };
    update(&player);
    update(&player); // starts transitioning right

    var i: u32 = 0;
    while (i < map_types.TRANSITION_FRAMES) : (i += 1) update(&player);

    try testing.expect(!map_types.transition.active);
    try testing.expectEqual(room_types.Side.left, map_types.entered_from.?);
    try testing.expectEqual(@as(u32, 1), map_types.room_index);
    try testing.expect(!room_types.active_door_sides[@intFromEnum(room_types.Side.left)]); // no way back
    try testing.expect(room_types.active_door_sides[@intFromEnum(room_types.Side.right)]);
    try testing.expectEqual(room_types.TILE_SIZE, player.x);
}
