// The active room: a single-screen tile grid exactly filling WASM4's
// 160x160 screen, so there's no camera/scroll yet (see CLAUDE.md).

pub const TILE_SIZE: f32 = 8;
pub const GRID_W: u32 = 20;
pub const GRID_H: u32 = 20;

pub const TileId = enum(u8) { empty, ground, wall };

pub const Room = struct {
    tiles: [GRID_H][GRID_W]TileId = .{[_]TileId{.empty} ** GRID_W} ** GRID_H,

    pub fn isSolid(self: *const Room, tx: i32, ty: i32) bool {
        if (tx < 0 or ty < 0 or tx >= GRID_W or ty >= GRID_H) return true;
        return self.tiles[@intCast(ty)][@intCast(tx)] != .empty;
    }
};

// One active room at a time -- every module reaches it through `isSolid`
// below rather than a hidden global.
pub var active: Room = .{};

// Free-function form of Room.isSolid, matching TileQuery's plain-function-
// pointer shape (a bound method can't be taken as one).
pub fn isSolid(tx: i32, ty: i32) bool {
    return active.isSolid(tx, ty);
}

test "isSolid treats out-of-bounds tiles as solid, keeping entities on-screen" {
    const testing = @import("std").testing;
    active = .{};
    try testing.expect(isSolid(-1, 0));
    try testing.expect(isSolid(@intCast(GRID_W), 0));
    try testing.expect(isSolid(0, -1));
    try testing.expect(isSolid(0, @intCast(GRID_H)));
}

test "isSolid reflects the tile grid for in-bounds coordinates" {
    const testing = @import("std").testing;
    active = .{};
    try testing.expect(!isSolid(5, 5));
    active.tiles[5][5] = .ground;
    try testing.expect(isSolid(5, 5));
}
