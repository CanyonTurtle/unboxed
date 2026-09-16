// One room: a 32x32 grid of 5px tiles exactly filling WASM4's 160x160
// screen. Rooms connect into a graph (map.types.zig) via their 4 sides.

pub const TILE_SIZE: f32 = 5;
pub const GRID_W: u32 = 32;
pub const GRID_H: u32 = 32;

pub const TileId = enum(u8) { empty, ground, wall };

// room.sim.generate always lays its solid ground floor here -- shared so
// left/right exits (below) can sit at a height the player can just walk to.
pub const FLOOR_ROW: u32 = GRID_H - 2;

pub const Room = struct {
    tiles: [GRID_H][GRID_W]TileId = .{[_]TileId{.empty} ** GRID_W} ** GRID_H,
};

// One active room at a time -- every module reaches it through `isSolid`
// below rather than a hidden global.
pub var active: Room = .{};

// A room borders 4 neighbors; each side either has no neighbor (map edge,
// permanently solid) or a gap that starts closed until map.sim breaks it.
pub const Side = enum(u2) { up, down, left, right };
const ALL_SIDES = [4]Side{ .up, .down, .left, .right };

const EXIT_SPAN: u32 = 3; // tiles wide, centered on the side

pub const TileSpan = struct { tx0: u32, tx1: u32, ty0: u32, ty1: u32 };

// The fixed tile range a side's gap occupies, whether or not it's open yet.
// up/down sit mid-wall (real platforming to reach); left/right sit at floor height.
pub fn exitSpan(side: Side) TileSpan {
    const mid_x = GRID_W / 2;
    const half = EXIT_SPAN / 2;
    return switch (side) {
        .up => .{ .tx0 = mid_x - half, .tx1 = mid_x + half, .ty0 = 0, .ty1 = 0 },
        .down => .{ .tx0 = mid_x - half, .tx1 = mid_x + half, .ty0 = GRID_H - 1, .ty1 = GRID_H - 1 },
        .left => .{ .tx0 = 0, .tx1 = 0, .ty0 = FLOOR_ROW - EXIT_SPAN + 1, .ty1 = FLOOR_ROW },
        .right => .{ .tx0 = GRID_W - 1, .tx1 = GRID_W - 1, .ty0 = FLOOR_ROW - EXIT_SPAN + 1, .ty1 = FLOOR_ROW },
    };
}

// Which sides of the *currently active* room have an open gap -- map.sim
// writes this whenever it loads a room or breaks a wall through it.
pub var active_open_sides: [4]bool = [_]bool{false} ** 4;

pub fn isOpenExitTile(tx: i32, ty: i32) bool {
    if (tx < 0 or ty < 0) return false;
    const utx: u32 = @intCast(tx);
    const uty: u32 = @intCast(ty);
    for (ALL_SIDES, 0..) |side, i| {
        if (!active_open_sides[i]) continue;
        const span = exitSpan(side);
        if (utx >= span.tx0 and utx <= span.tx1 and uty >= span.ty0 and uty <= span.ty1) return true;
    }
    return false;
}

pub fn isSolid(tx: i32, ty: i32) bool {
    if (tx < 0 or ty < 0 or tx >= GRID_W or ty >= GRID_H) return true;
    const tile = active.tiles[@intCast(ty)][@intCast(tx)];
    if (tile == .wall and isOpenExitTile(tx, ty)) return false;
    return tile != .empty;
}

test "isSolid treats out-of-bounds tiles as solid, keeping entities on-screen" {
    const testing = @import("std").testing;
    active = .{};
    active_open_sides = [_]bool{false} ** 4;
    try testing.expect(isSolid(-1, 0));
    try testing.expect(isSolid(@intCast(GRID_W), 0));
    try testing.expect(isSolid(0, -1));
    try testing.expect(isSolid(0, @intCast(GRID_H)));
}

test "isSolid reflects the tile grid for in-bounds coordinates" {
    const testing = @import("std").testing;
    active = .{};
    active_open_sides = [_]bool{false} ** 4;
    try testing.expect(!isSolid(5, 5));
    active.tiles[5][5] = .ground;
    try testing.expect(isSolid(5, 5));
}

test "an open side's gap tiles stop being solid, but the rest of that side doesn't" {
    const testing = @import("std").testing;
    active = .{};
    for (0..GRID_W) |tx| active.tiles[0][tx] = .wall;
    active_open_sides = [_]bool{ true, false, false, false }; // up

    const span = exitSpan(.up);
    try testing.expect(!isSolid(@intCast(span.tx0), 0));
    try testing.expect(!isSolid(@intCast(span.tx1), 0));
    try testing.expect(isSolid(@intCast(span.tx0 - 1), 0));
    try testing.expect(isSolid(@intCast(span.tx1 + 1), 0));
}
