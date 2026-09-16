// Room generation-on-demand, transitions, and wall-digging -- the one file
// that knows both the room graph and the per-room entity arrays it saves/restores.

const w4 = @import("../wasm4.zig");
const input = @import("../core/core.input.zig");
const rng_mod = @import("../core/core.rng.zig");
const room_types = @import("../room/room.types.zig");
const room_sim = @import("../room/room.sim.zig");
const pot_types = @import("../pot/pot.types.zig");
const item_types = @import("../item/item.types.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const powerup_types = @import("../powerup/powerup.types.zig");
const platform_types = @import("../platform/platform.types.zig");
const platform_sim = @import("../platform/platform.sim.zig");
const char_types = @import("../character/character.types.zig");
const map_types = @import("map.types.zig");

const ALL_SIDES = [4]room_types.Side{ .up, .down, .left, .right };
const SEED_BASE: u32 = 0xc0ffee;

// Sustained-dig charge per side of the *active* room only -- never
// persisted, so leaving mid-dig and coming back starts the charge over.
var dig_progress: [4]u16 = [_]u16{0} ** 4;

fn seedFor(rx: u32, ry: u32) u32 {
    return SEED_BASE +% rx *% 73856093 +% ry *% 19349663;
}

fn tilePx(t: u32) f32 {
    return @as(f32, @floatFromInt(t)) * room_types.TILE_SIZE;
}

// Fills in a room graph cell the first time it's visited (or dug towards);
// a no-op after that, so the room's layout and remaining enemies persist.
fn generateRoom(rx: u32, ry: u32) void {
    var save = &map_types.rooms[ry][rx];
    if (save.generated) return;
    save.generated = true;

    var rng = rng_mod.Rng{ .state = seedFor(rx, ry) };
    room_sim.generate(&save.room, &rng);

    for (&save.pots) |*pot| {
        const spot = room_sim.randomFloorSpot(&save.room, &rng);
        pot.* = .{ .x = tilePx(spot.tx), .y = tilePx(spot.ty) };
    }
    for (&save.items) |*item| item.* = .{};

    const depth = map_types.depth(rx, ry);
    const depth_usize: usize = @intCast(depth);
    const enemy_count: usize = if (depth == 0) 0 else 1 + @min(depth_usize - 1, enemy_types.MAX_COUNT - 1);
    for (&save.enemies, 0..) |*enemy, i| {
        if (i < enemy_count) {
            const spot = room_sim.randomFloorSpot(&save.room, &rng);
            enemy.* = .{ .x = tilePx(spot.tx), .y = tilePx(spot.ty), .alive = true };
        } else {
            enemy.* = .{};
        }
    }

    if (depth == 0) {
        save.powerup = .{};
    } else {
        const spot = room_sim.randomFloorSpot(&save.room, &rng);
        save.powerup = .{
            .x = tilePx(spot.tx),
            .y = tilePx(spot.ty),
            .kind = if (depth >= 2) .double_jump else .extra_hp,
            .placed = true,
        };
    }

    // Anchored near the ceiling, well clear of the side walls; hang length
    // varies so not every room's swing settles at the same height.
    for (&save.platforms) |*plat| {
        const left_tx = rng.between(4, room_types.GRID_W - 8);
        const hang_tiles = rng.between(8, 20);
        platform_sim.spawn(plat, tilePx(left_tx), tilePx(3), tilePx(hang_tiles));
    }
}

fn saveActive() void {
    var save = &map_types.rooms[map_types.current_ry][map_types.current_rx];
    save.room = room_types.active;
    save.pots = pot_types.pots;
    save.items = item_types.items;
    save.enemies = enemy_types.enemies;
    save.powerup = powerup_types.active;
    save.platforms = platform_types.platforms;
}

fn syncOpenSides() void {
    for (ALL_SIDES, 0..) |side, i| {
        room_types.active_open_sides[i] = map_types.isBroken(map_types.current_rx, map_types.current_ry, side);
    }
}

fn loadActive() void {
    const save = &map_types.rooms[map_types.current_ry][map_types.current_rx];
    room_types.active = save.room;
    pot_types.pots = save.pots;
    item_types.items = save.items;
    enemy_types.enemies = save.enemies;
    powerup_types.active = save.powerup;
    platform_types.platforms = save.platforms;
    dig_progress = [_]u16{0} ** 4;
    room_types.active_dig_ratio = [_]f32{0} ** 4;
    syncOpenSides();
}

fn enterRoom(rx: u32, ry: u32) void {
    saveActive();
    generateRoom(rx, ry);
    map_types.current_rx = rx;
    map_types.current_ry = ry;
    loadActive();
}

// Resets the whole map and starts a fresh run in the start room.
pub fn initNewMap() void {
    map_types.rooms = .{[_]map_types.RoomSave{.{}} ** map_types.MAP_W} ** map_types.MAP_H;
    map_types.broken_h = .{[_]bool{false} ** (map_types.MAP_W - 1)} ** map_types.MAP_H;
    map_types.broken_v = .{[_]bool{false} ** map_types.MAP_W} ** (map_types.MAP_H - 1);
    map_types.current_rx = map_types.START_RX;
    map_types.current_ry = map_types.START_RY;
    generateRoom(map_types.START_RX, map_types.START_RY);
    loadActive();
}

pub fn isRoomCleared() bool {
    for (enemy_types.enemies) |e| {
        if (e.alive) return false;
    }
    return true;
}

fn overlapsRange(pos: f32, size: f32, min: f32, max: f32) bool {
    return pos < max and pos + size > min;
}

// Is the player's box touching the (still-solid) wall at this side's gap,
// aligned with the gap rather than elsewhere along that same wall.
fn touchingSide(player: *const char_types.Character, side: room_types.Side) bool {
    const ts = room_types.TILE_SIZE;
    const room_w = tilePx(room_types.GRID_W);
    const room_h = tilePx(room_types.GRID_H);
    const span = room_types.exitSpan(side);
    return switch (side) {
        .left => player.x <= ts and overlapsRange(player.y, char_types.HEIGHT, tilePx(span.ty0), tilePx(span.ty1 + 1)),
        .right => player.x + char_types.WIDTH >= room_w - ts and overlapsRange(player.y, char_types.HEIGHT, tilePx(span.ty0), tilePx(span.ty1 + 1)),
        .up => player.y <= ts and overlapsRange(player.x, char_types.WIDTH, tilePx(span.tx0), tilePx(span.tx1 + 1)),
        .down => player.y + char_types.HEIGHT >= room_h - ts and overlapsRange(player.x, char_types.WIDTH, tilePx(span.tx0), tilePx(span.tx1 + 1)),
    };
}

fn digInput(gamepad: u8, side: room_types.Side) bool {
    return switch (side) {
        .left => input.held(gamepad, w4.BUTTON_LEFT),
        .right => input.held(gamepad, w4.BUTTON_RIGHT),
        .up => input.held(gamepad, w4.BUTTON_UP),
        .down => input.held(gamepad, w4.BUTTON_DOWN),
    };
}

fn breakThrough(side: room_types.Side) void {
    map_types.setBroken(map_types.current_rx, map_types.current_ry, side);
    room_types.active_open_sides[@intFromEnum(side)] = true;
    // Generated right away so it already has content the instant you walk in.
    if (map_types.neighbor(map_types.current_rx, map_types.current_ry, side)) |n| generateRoom(n.rx, n.ry);
}

// Exits only open once every enemy in the room is down. `active_dig_ratio`
// is written purely for room.render's feedback -- it never gates anything.
fn updateDigging(gamepad: u8, player: *const char_types.Character) void {
    if (!isRoomCleared()) {
        dig_progress = [_]u16{0} ** 4;
        room_types.active_dig_ratio = [_]f32{0} ** 4;
        return;
    }
    for (ALL_SIDES, 0..) |side, i| {
        if (room_types.active_open_sides[i]) {
            dig_progress[i] = 0;
            room_types.active_dig_ratio[i] = 0;
            continue;
        }
        const toughness = map_types.toughnessFor(map_types.current_rx, map_types.current_ry, side) orelse {
            dig_progress[i] = 0;
            room_types.active_dig_ratio[i] = 0;
            continue;
        };
        if (touchingSide(player, side) and digInput(gamepad, side)) {
            dig_progress[i] += 1;
            if (dig_progress[i] >= toughness) breakThrough(side);
        } else {
            dig_progress[i] = 0;
        }
        room_types.active_dig_ratio[i] = @as(f32, @floatFromInt(dig_progress[i])) / @as(f32, @floatFromInt(toughness));
    }
}

fn revealPowerupOnceCleared() void {
    if (powerup_types.active.placed and !powerup_types.active.revealed and isRoomCleared()) {
        powerup_types.active.revealed = true;
    }
}

// Walking fully past an open gap on the active room's edge hands off to
// the neighbor room, entering it at the matching point on its own edge.
fn updateEdgeCrossing(player: *char_types.Character) void {
    const room_w = tilePx(room_types.GRID_W);
    const room_h = tilePx(room_types.GRID_H);
    if (player.x <= 0 and room_types.active_open_sides[@intFromEnum(room_types.Side.left)]) {
        if (map_types.neighbor(map_types.current_rx, map_types.current_ry, .left)) |n| {
            enterRoom(n.rx, n.ry);
            player.x = room_w - char_types.WIDTH - 1;
        }
    } else if (player.x + char_types.WIDTH >= room_w and room_types.active_open_sides[@intFromEnum(room_types.Side.right)]) {
        if (map_types.neighbor(map_types.current_rx, map_types.current_ry, .right)) |n| {
            enterRoom(n.rx, n.ry);
            player.x = 1;
        }
    } else if (player.y <= 0 and room_types.active_open_sides[@intFromEnum(room_types.Side.up)]) {
        if (map_types.neighbor(map_types.current_rx, map_types.current_ry, .up)) |n| {
            enterRoom(n.rx, n.ry);
            player.y = room_h - char_types.HEIGHT - 1;
        }
    } else if (player.y + char_types.HEIGHT >= room_h and room_types.active_open_sides[@intFromEnum(room_types.Side.down)]) {
        if (map_types.neighbor(map_types.current_rx, map_types.current_ry, .down)) |n| {
            enterRoom(n.rx, n.ry);
            player.y = 1;
        }
    }
}

pub fn update(gamepad: u8, player: *char_types.Character) void {
    updateEdgeCrossing(player);
    revealPowerupOnceCleared();
    updateDigging(gamepad, player);
}

const testing = @import("std").testing;

test "initNewMap generates and loads the start room" {
    initNewMap();
    try testing.expect(map_types.rooms[map_types.START_RY][map_types.START_RX].generated);
    try testing.expectEqual(map_types.START_RX, map_types.current_rx);
    try testing.expectEqual(map_types.START_RY, map_types.current_ry);
}

test "the start room has no enemies and no powerup, so it's cleared already" {
    initNewMap();
    try testing.expect(isRoomCleared());
    try testing.expect(!powerup_types.active.placed);
}

test "a generated non-start room has at least one enemy and a placed powerup" {
    initNewMap();
    generateRoom(map_types.START_RX + 1, map_types.START_RY);
    const save = map_types.rooms[map_types.START_RY][map_types.START_RX + 1];
    var alive_count: u32 = 0;
    for (save.enemies) |e| {
        if (e.alive) alive_count += 1;
    }
    try testing.expect(alive_count >= 1);
    try testing.expect(save.powerup.placed);
}

test "digging a cleared side long enough breaks through and opens it" {
    initNewMap();
    try testing.expect(isRoomCleared()); // start room has no enemies
    const toughness = map_types.toughnessFor(map_types.START_RX, map_types.START_RY, .right).?;

    var player = char_types.Character{ .x = tilePx(room_types.GRID_W) - room_types.TILE_SIZE, .y = tilePx(room_types.FLOOR_ROW) - char_types.HEIGHT };
    var frame: u32 = 0;
    while (frame < toughness) : (frame += 1) update(w4.BUTTON_RIGHT, &player);

    try testing.expect(room_types.active_open_sides[@intFromEnum(room_types.Side.right)]);
    try testing.expect(map_types.isBroken(map_types.START_RX, map_types.START_RY, .right));
}

test "walking through an open gap enters the neighboring room" {
    initNewMap();
    // Bypassing breakThrough, so mirror what it would do to active_open_sides.
    map_types.setBroken(map_types.START_RX, map_types.START_RY, .right);
    room_types.active_open_sides[@intFromEnum(room_types.Side.right)] = true;

    var player = char_types.Character{ .x = tilePx(room_types.GRID_W) - char_types.WIDTH, .y = tilePx(16) };
    update(0, &player);

    try testing.expectEqual(map_types.START_RX + 1, map_types.current_rx);
    try testing.expectEqual(map_types.START_RY, map_types.current_ry);
    try testing.expectEqual(@as(f32, 1), player.x);
}
