// The room graph: a small grid of rooms, each remembering its own room/
// entities once generated, so leaving and returning preserves its state.

const room_types = @import("../room/room.types.zig");
const pot_types = @import("../pot/pot.types.zig");
const item_types = @import("../item/item.types.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const powerup_types = @import("../powerup/powerup.types.zig");
const platform_types = @import("../platform/platform.types.zig");

pub const MAP_W: u32 = 3;
pub const MAP_H: u32 = 3;
pub const START_RX: u32 = 1;
pub const START_RY: u32 = 1;

// How long (frames) sustained digging takes -- scales with the depth of
// the room on the other side, so a better reward takes more commitment.
pub const BASE_TOUGHNESS: u16 = 90;
pub const TOUGHNESS_STEP: u16 = 90;

pub const RoomSave = struct {
    generated: bool = false,
    room: room_types.Room = .{},
    pots: [pot_types.MAX_COUNT]pot_types.Pot = [_]pot_types.Pot{.{}} ** pot_types.MAX_COUNT,
    items: [item_types.MAX_COUNT]item_types.Item = [_]item_types.Item{.{}} ** item_types.MAX_COUNT,
    enemies: [enemy_types.MAX_COUNT]enemy_types.Enemy = [_]enemy_types.Enemy{.{}} ** enemy_types.MAX_COUNT,
    powerup: powerup_types.Powerup = .{},
    platforms: [platform_types.MAX_COUNT]platform_types.SwingPlatform = [_]platform_types.SwingPlatform{.{}} ** platform_types.MAX_COUNT,
};

// Each RoomSave costs ~1.3KB (mostly its 32x32 tile grid) -- fixed arrays,
// no allocator, since WASM-4 carts get one fixed 64KB memory page total.
pub var rooms: [MAP_H][MAP_W]RoomSave = .{[_]RoomSave{.{}} ** MAP_W} ** MAP_H;

pub var current_rx: u32 = START_RX;
pub var current_ry: u32 = START_RY;

// Shared per-edge state (one bool per wall, not per room per side):
// broken_h[ry][rx] is the wall between (rx,ry)-(rx+1,ry); broken_v likewise for (rx,ry)-(rx,ry+1).
pub var broken_h: [MAP_H][MAP_W - 1]bool = .{[_]bool{false} ** (MAP_W - 1)} ** MAP_H;
pub var broken_v: [MAP_H - 1][MAP_W]bool = .{[_]bool{false} ** MAP_W} ** (MAP_H - 1);

fn absDiff(a: u32, b: u32) u32 {
    return if (a > b) a - b else b - a;
}

// Manhattan distance from the start room -- the fewest room-to-room hops
// (only cardinal moves exist) needed to reach it, i.e. how deep it is.
pub fn depth(rx: u32, ry: u32) u32 {
    return absDiff(rx, START_RX) + absDiff(ry, START_RY);
}

pub fn neighbor(rx: u32, ry: u32, side: room_types.Side) ?struct { rx: u32, ry: u32 } {
    return switch (side) {
        .up => if (ry == 0) null else .{ .rx = rx, .ry = ry - 1 },
        .down => if (ry >= MAP_H - 1) null else .{ .rx = rx, .ry = ry + 1 },
        .left => if (rx == 0) null else .{ .rx = rx - 1, .ry = ry },
        .right => if (rx >= MAP_W - 1) null else .{ .rx = rx + 1, .ry = ry },
    };
}

pub fn isBroken(rx: u32, ry: u32, side: room_types.Side) bool {
    return switch (side) {
        .right => rx < MAP_W - 1 and broken_h[ry][rx],
        .left => rx > 0 and broken_h[ry][rx - 1],
        .down => ry < MAP_H - 1 and broken_v[ry][rx],
        .up => ry > 0 and broken_v[ry - 1][rx],
    };
}

pub fn setBroken(rx: u32, ry: u32, side: room_types.Side) void {
    switch (side) {
        .right => if (rx < MAP_W - 1) {
            broken_h[ry][rx] = true;
        },
        .left => if (rx > 0) {
            broken_h[ry][rx - 1] = true;
        },
        .down => if (ry < MAP_H - 1) {
            broken_v[ry][rx] = true;
        },
        .up => if (ry > 0) {
            broken_v[ry - 1][rx] = true;
        },
    }
}

// How long digging this side takes, or null if there's no room over there
// to dig into at all (a permanent map-edge wall).
pub fn toughnessFor(rx: u32, ry: u32, side: room_types.Side) ?u16 {
    const n = neighbor(rx, ry, side) orelse return null;
    return BASE_TOUGHNESS + @as(u16, @intCast(depth(n.rx, n.ry))) * TOUGHNESS_STEP;
}

const testing = @import("std").testing;

test "depth is 0 at the start room and grows with Chebyshev distance" {
    try testing.expectEqual(@as(u32, 0), depth(START_RX, START_RY));
    try testing.expectEqual(@as(u32, 1), depth(START_RX + 1, START_RY));
    try testing.expectEqual(@as(u32, 1), depth(START_RX, START_RY - 1));
}

test "neighbor returns null at the map's edges" {
    try testing.expect(neighbor(0, 0, .up) == null);
    try testing.expect(neighbor(0, 0, .left) == null);
    try testing.expect(neighbor(MAP_W - 1, MAP_H - 1, .right) == null);
    try testing.expect(neighbor(MAP_W - 1, MAP_H - 1, .down) == null);
}

test "setBroken on one room's side is visible from the neighbor's own side" {
    broken_h = .{[_]bool{false} ** (MAP_W - 1)} ** MAP_H;
    broken_v = .{[_]bool{false} ** MAP_W} ** (MAP_H - 1);
    setBroken(START_RX, START_RY, .right);
    try testing.expect(isBroken(START_RX, START_RY, .right));
    try testing.expect(isBroken(START_RX + 1, START_RY, .left));
    try testing.expect(!isBroken(START_RX, START_RY, .up));
}

test "toughnessFor is null past the map edge and scales with the neighbor's depth" {
    try testing.expect(toughnessFor(0, 0, .left) == null);

    // Start -> an edge-adjacent room (depth 1) vs. an edge room -> a corner
    // (depth 2): the corner-bound wall should take strictly longer to dig.
    const shallow = toughnessFor(START_RX, START_RY, .right).?;
    const deeper = toughnessFor(MAP_W - 1, START_RY, .down).?;
    try testing.expectEqual(BASE_TOUGHNESS + TOUGHNESS_STEP, shallow);
    try testing.expect(deeper > shallow);
}
