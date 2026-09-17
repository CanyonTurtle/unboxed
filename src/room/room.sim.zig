// Procedural generation plus a spawn-point query, operating on an explicit
// `*Room` (never `types.active`) so map.sim can generate a room that isn't the active one.

const types = @import("room.types.zig");
const rng_mod = @import("../core/core.rng.zig");

// Border walls and a solid ground floor one row up from the bottom -- no
// interior platforms, since the player floats and doesn't need footing.
pub fn generate(room: *types.Room) void {
    for (0..types.GRID_H) |ty| {
        for (0..types.GRID_W) |tx| {
            const border = tx == 0 or ty == 0 or tx == types.GRID_W - 1 or ty == types.GRID_H - 1;
            room.tiles[ty][tx] = if (border) .wall else .empty;
        }
    }

    for (1..types.GRID_W - 1) |tx| room.tiles[types.FLOOR_ROW][tx] = .ground;
}

// A random empty interior tile -- nothing needs to rest on solid ground
// beneath it, since every entity floats freely in the open room.
pub fn randomOpenSpot(room: *const types.Room, rng: *rng_mod.Rng) struct { tx: u32, ty: u32 } {
    var attempts: u32 = 0;
    while (attempts < 300) : (attempts += 1) {
        const tx = rng.between(1, types.GRID_W - 2);
        const ty = rng.between(1, types.GRID_H - 2);
        if (room.tiles[ty][tx] == .empty) return .{ .tx = tx, .ty = ty };
    }
    return .{ .tx = 2, .ty = 2 };
}

test "generate surrounds the room with solid border walls" {
    const testing = @import("std").testing;
    var room: types.Room = .{};
    generate(&room);
    for (0..types.GRID_W) |tx| {
        try testing.expect(room.tiles[0][tx] == .wall);
        try testing.expect(room.tiles[types.GRID_H - 1][tx] == .wall);
    }
    for (0..types.GRID_H) |ty| {
        try testing.expect(room.tiles[ty][0] == .wall);
        try testing.expect(room.tiles[ty][types.GRID_W - 1] == .wall);
    }
}

test "generate lays a full solid ground floor" {
    const testing = @import("std").testing;
    var room: types.Room = .{};
    generate(&room);
    for (1..types.GRID_W - 1) |tx| {
        try testing.expect(room.tiles[types.FLOOR_ROW][tx] != .empty);
    }
}

test "generate leaves the whole interior above the floor open" {
    const testing = @import("std").testing;
    var room: types.Room = .{};
    generate(&room);
    var ty: u32 = 1;
    while (ty < types.FLOOR_ROW) : (ty += 1) {
        for (1..types.GRID_W - 1) |tx| {
            try testing.expect(room.tiles[ty][tx] == .empty);
        }
    }
}

test "randomOpenSpot always returns an empty interior tile" {
    const testing = @import("std").testing;
    var room: types.Room = .{};
    var rng = rng_mod.Rng{ .state = 123 };
    generate(&room);
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        const spot = randomOpenSpot(&room, &rng);
        try testing.expect(room.tiles[spot.ty][spot.tx] == .empty);
        try testing.expect(spot.tx >= 1 and spot.tx < types.GRID_W - 1);
        try testing.expect(spot.ty >= 1 and spot.ty < types.GRID_H - 1);
    }
}
