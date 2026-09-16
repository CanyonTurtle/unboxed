// Shared axis-aligned box math and tile collision: `Rect` for overlap
// checks, `moveAndCollide` for moving against a room's tiles.

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn overlaps(a: Rect, b: Rect) bool {
        return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y;
    }
};

// Duck-typed tile lookup, so this module never depends on any one room's
// grid type -- callers pass their own `isSolid` function pointer.
pub const TileQuery = struct {
    tile_size: f32,
    isSolid: *const fn (tile_x: i32, tile_y: i32) bool,
};

pub const MoveResult = struct {
    on_ground: bool = false,
    hit_wall: bool = false,
};

fn tileFloor(v: f32, tile_size: f32) i32 {
    return @intFromFloat(@floor(v / tile_size));
}

const TileHit = struct { tx: i32, ty: i32 };

fn firstSolidTile(x: f32, y: f32, w: f32, h: f32, tiles: TileQuery) ?TileHit {
    const ts = tiles.tile_size;
    const tx0 = tileFloor(x, ts);
    const tx1 = tileFloor(x + w - 0.001, ts);
    const ty0 = tileFloor(y, ts);
    const ty1 = tileFloor(y + h - 0.001, ts);
    var ty = ty0;
    while (ty <= ty1) : (ty += 1) {
        var tx = tx0;
        while (tx <= tx1) : (tx += 1) {
            if (tiles.isSolid(tx, ty)) return .{ .tx = tx, .ty = ty };
        }
    }
    return null;
}

// Moves an axis-aligned box by (vel_x, vel_y), one axis at a time, stopping
// at the first solid tile on that axis and zeroing that axis's velocity.
pub fn moveAndCollide(x: *f32, y: *f32, w: f32, h: f32, vel_x: *f32, vel_y: *f32, tiles: TileQuery) MoveResult {
    var result = MoveResult{};
    const ts = tiles.tile_size;

    x.* += vel_x.*;
    if (firstSolidTile(x.*, y.*, w, h, tiles)) |hit| {
        if (vel_x.* > 0) {
            x.* = @as(f32, @floatFromInt(hit.tx)) * ts - w;
        } else if (vel_x.* < 0) {
            x.* = @as(f32, @floatFromInt(hit.tx + 1)) * ts;
        }
        vel_x.* = 0;
        result.hit_wall = true;
    }

    y.* += vel_y.*;
    if (firstSolidTile(x.*, y.*, w, h, tiles)) |hit| {
        if (vel_y.* > 0) {
            y.* = @as(f32, @floatFromInt(hit.ty)) * ts - h;
            result.on_ground = true;
        } else if (vel_y.* < 0) {
            y.* = @as(f32, @floatFromInt(hit.ty + 1)) * ts;
        }
        vel_y.* = 0;
    }

    // A box resting exactly on a boundary (vel_y == 0) never triggers the
    // check above -- probe one pixel down so standing still isn't seen as free-fall.
    if (!result.on_ground and firstSolidTile(x.*, y.* + 1, w, h, tiles) != null) {
        result.on_ground = true;
    }

    return result;
}

const testing = @import("std").testing;

test "Rect.overlaps is true for intersecting boxes and false for separated ones" {
    const a = Rect{ .x = 0, .y = 0, .w = 10, .h = 10 };
    try testing.expect(a.overlaps(.{ .x = 5, .y = 5, .w = 10, .h = 10 }));
    try testing.expect(!a.overlaps(.{ .x = 20, .y = 0, .w = 10, .h = 10 }));
    try testing.expect(!a.overlaps(.{ .x = 0, .y = 20, .w = 10, .h = 10 }));
}

const TestGrid = struct {
    var solid: [8][8]bool = [_][8]bool{[_]bool{false} ** 8} ** 8;

    fn isSolid(tx: i32, ty: i32) bool {
        if (tx < 0 or ty < 0 or tx >= 8 or ty >= 8) return true;
        return solid[@intCast(ty)][@intCast(tx)];
    }

    fn reset() void {
        solid = [_][8]bool{[_]bool{false} ** 8} ** 8;
    }
};

test "moveAndCollide lands on a solid floor and zeroes downward velocity" {
    TestGrid.reset();
    TestGrid.solid[4][2] = true; // floor tile directly below the box
    const tiles = TileQuery{ .tile_size = 8, .isSolid = &TestGrid.isSolid };

    var x: f32 = 16;
    var y: f32 = 24; // sits just above the floor tile at ty=4 (y=32)
    var vx: f32 = 0;
    var vy: f32 = 4;
    const result = moveAndCollide(&x, &y, 8, 8, &vx, &vy, tiles);

    try testing.expect(result.on_ground);
    try testing.expectEqual(@as(f32, 0), vy);
    try testing.expectEqual(@as(f32, 32 - 8), y);
}

test "moveAndCollide stops horizontal movement at a wall" {
    TestGrid.reset();
    TestGrid.solid[0][3] = true;
    const tiles = TileQuery{ .tile_size = 8, .isSolid = &TestGrid.isSolid };

    var x: f32 = 16;
    var y: f32 = 0;
    var vx: f32 = 4;
    var vy: f32 = 0;
    const result = moveAndCollide(&x, &y, 8, 8, &vx, &vy, tiles);

    try testing.expect(result.hit_wall);
    try testing.expectEqual(@as(f32, 0), vx);
    try testing.expectEqual(@as(f32, 24 - 8), x);
}

test "moveAndCollide reports on_ground for a box resting on a boundary with zero velocity" {
    TestGrid.reset();
    TestGrid.solid[4][2] = true;
    const tiles = TileQuery{ .tile_size = 8, .isSolid = &TestGrid.isSolid };

    var x: f32 = 16;
    var y: f32 = 24; // exactly resting on top of the floor tile
    var vx: f32 = 0;
    var vy: f32 = 0;
    const result = moveAndCollide(&x, &y, 8, 8, &vx, &vy, tiles);

    try testing.expect(result.on_ground);
}
