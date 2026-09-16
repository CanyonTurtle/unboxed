// Procedural generation plus a spawn-point query, operating on an explicit
// `*Room` (never `types.active`) so map.sim can generate a room that isn't the active one.

const types = @import("room.types.zig");
const rng_mod = @import("../core/core.rng.zig");

const PLATFORM_MIN_COUNT = 4;
const PLATFORM_MAX_COUNT = 8;
const PLATFORM_MIN_WIDTH = 2;
const PLATFORM_MAX_WIDTH = 6;
// Tile rows kept clear above the floor -- fewer would leave a gap shorter
// than the 8px character, sealing the floor (and its doors) off entirely.
const FLOOR_CLEARANCE_ROWS = 3;

// Border walls, a solid ground floor one row up from the bottom, and a
// random handful of floating platforms at varied heights/widths/counts.
pub fn generate(room: *types.Room, rng: *rng_mod.Rng) void {
    for (0..types.GRID_H) |ty| {
        for (0..types.GRID_W) |tx| {
            const border = tx == 0 or ty == 0 or tx == types.GRID_W - 1 or ty == types.GRID_H - 1;
            room.tiles[ty][tx] = if (border) .wall else .empty;
        }
    }

    const floor_y = types.FLOOR_ROW;
    for (1..types.GRID_W - 1) |tx| room.tiles[floor_y][tx] = .ground;

    const platform_count = rng.between(PLATFORM_MIN_COUNT, PLATFORM_MAX_COUNT);
    var i: u32 = 0;
    while (i < platform_count) : (i += 1) {
        const py = rng.between(4, floor_y - FLOOR_CLEARANCE_ROWS - 1);
        const px = rng.between(2, types.GRID_W - 6);
        const width = rng.between(PLATFORM_MIN_WIDTH, PLATFORM_MAX_WIDTH);
        var w: u32 = 0;
        while (w < width) : (w += 1) {
            const tx = px + w;
            if (tx < types.GRID_W - 1) room.tiles[py][tx] = .ground;
        }
    }
}

// A random empty tile with solid ground beneath it, restricted to the
// floating platforms -- the floor spans the whole room, so unrestricted sampling would land there.
pub fn randomFloorSpot(room: *const types.Room, rng: *rng_mod.Rng) struct { tx: u32, ty: u32 } {
    var attempts: u32 = 0;
    while (attempts < 300) : (attempts += 1) {
        const tx = rng.between(1, types.GRID_W - 2);
        const ty = rng.between(1, types.FLOOR_ROW - 2);
        if (room.tiles[ty][tx] == .empty and room.tiles[ty + 1][tx] != .empty) {
            return .{ .tx = tx, .ty = ty };
        }
    }
    var ty: u32 = 1;
    while (ty < types.FLOOR_ROW - 1) : (ty += 1) {
        var tx: u32 = 1;
        while (tx < types.GRID_W - 1) : (tx += 1) {
            if (room.tiles[ty][tx] == .empty and room.tiles[ty + 1][tx] != .empty) {
                return .{ .tx = tx, .ty = ty };
            }
        }
    }
    return .{ .tx = 2, .ty = types.GRID_H - 3 };
}

test "generate surrounds the room with solid border walls" {
    const testing = @import("std").testing;
    var room: types.Room = .{};
    var rng = rng_mod.Rng{ .state = 42 };
    generate(&room, &rng);
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
    var rng = rng_mod.Rng{ .state = 7 };
    generate(&room, &rng);
    for (1..types.GRID_W - 1) |tx| {
        try testing.expect(room.tiles[types.FLOOR_ROW][tx] != .empty);
    }
}

test "generate never places a platform close enough to seal off the floor" {
    const testing = @import("std").testing;
    var seed: u32 = 0;
    while (seed < 30) : (seed += 1) {
        var room: types.Room = .{};
        var rng = rng_mod.Rng{ .state = seed };
        generate(&room, &rng);
        var ty = types.FLOOR_ROW - FLOOR_CLEARANCE_ROWS;
        while (ty < types.FLOOR_ROW) : (ty += 1) {
            for (1..types.GRID_W - 1) |tx| {
                try testing.expect(room.tiles[ty][tx] == .empty);
            }
        }
    }
}

test "randomFloorSpot always returns a tile with solid ground beneath it" {
    const testing = @import("std").testing;
    var room: types.Room = .{};
    var rng = rng_mod.Rng{ .state = 123 };
    generate(&room, &rng);
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        const spot = randomFloorSpot(&room, &rng);
        try testing.expect(room.tiles[spot.ty][spot.tx] == .empty);
        try testing.expect(room.tiles[spot.ty + 1][spot.tx] != .empty);
    }
}

test "randomFloorSpot never lands on the main floor -- only the floating platforms" {
    const testing = @import("std").testing;
    var seed: u32 = 0;
    while (seed < 30) : (seed += 1) {
        var room: types.Room = .{};
        var rng = rng_mod.Rng{ .state = seed };
        generate(&room, &rng);
        var i: u32 = 0;
        while (i < 10) : (i += 1) {
            const spot = randomFloorSpot(&room, &rng);
            try testing.expect(spot.ty < types.FLOOR_ROW - 1);
        }
    }
}
