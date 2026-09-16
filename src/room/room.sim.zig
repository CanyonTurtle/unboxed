// Procedural generation plus a spawn-point query. Knows nothing about
// characters/pots/enemies -- it only hands out empty tiles with solid ground beneath them.

const types = @import("room.types.zig");
const rng_mod = @import("../core/core.rng.zig");

const PLATFORM_COUNT = 4;
const PLATFORM_MIN_WIDTH = 2;
const PLATFORM_MAX_WIDTH = 4;

// Border walls, a solid ground floor one row up from the bottom, and a
// handful of floating platforms at random heights/widths.
pub fn generate(rng: *rng_mod.Rng) void {
    var room = &types.active;
    for (0..types.GRID_H) |ty| {
        for (0..types.GRID_W) |tx| {
            const border = tx == 0 or ty == 0 or tx == types.GRID_W - 1 or ty == types.GRID_H - 1;
            room.tiles[ty][tx] = if (border) .wall else .empty;
        }
    }

    const floor_y = types.GRID_H - 2;
    for (1..types.GRID_W - 1) |tx| room.tiles[floor_y][tx] = .ground;

    var i: u32 = 0;
    while (i < PLATFORM_COUNT) : (i += 1) {
        const py = rng.between(4, floor_y - 2);
        const px = rng.between(2, types.GRID_W - 6);
        const width = rng.between(PLATFORM_MIN_WIDTH, PLATFORM_MAX_WIDTH);
        var w: u32 = 0;
        while (w < width) : (w += 1) {
            const tx = px + w;
            if (tx < types.GRID_W - 1) room.tiles[py][tx] = .ground;
        }
    }
}

// A random empty tile with solid ground beneath it -- valid standing room
// for a spawn. Falls back to a fixed spot if no candidate turns up.
pub fn randomFloorSpot(rng: *rng_mod.Rng) struct { tx: u32, ty: u32 } {
    const room = &types.active;
    var attempts: u32 = 0;
    while (attempts < 100) : (attempts += 1) {
        const tx = rng.between(1, types.GRID_W - 2);
        const ty = rng.between(1, types.GRID_H - 3);
        if (room.tiles[ty][tx] == .empty and room.tiles[ty + 1][tx] != .empty) {
            return .{ .tx = tx, .ty = ty };
        }
    }
    return .{ .tx = 2, .ty = types.GRID_H - 3 };
}

test "generate surrounds the room with solid border walls" {
    const testing = @import("std").testing;
    var rng = rng_mod.Rng{ .state = 42 };
    generate(&rng);
    for (0..types.GRID_W) |tx| {
        try testing.expect(types.active.tiles[0][tx] == .wall);
        try testing.expect(types.active.tiles[types.GRID_H - 1][tx] == .wall);
    }
    for (0..types.GRID_H) |ty| {
        try testing.expect(types.active.tiles[ty][0] == .wall);
        try testing.expect(types.active.tiles[ty][types.GRID_W - 1] == .wall);
    }
}

test "generate lays a full solid ground floor" {
    const testing = @import("std").testing;
    var rng = rng_mod.Rng{ .state = 7 };
    generate(&rng);
    const floor_y = types.GRID_H - 2;
    for (1..types.GRID_W - 1) |tx| {
        try testing.expect(types.active.tiles[floor_y][tx] != .empty);
    }
}

test "randomFloorSpot always returns a tile with solid ground beneath it" {
    const testing = @import("std").testing;
    var rng = rng_mod.Rng{ .state = 123 };
    generate(&rng);
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        const spot = randomFloorSpot(&rng);
        try testing.expect(types.active.tiles[spot.ty][spot.tx] == .empty);
        try testing.expect(types.active.tiles[spot.ty + 1][spot.tx] != .empty);
    }
}
