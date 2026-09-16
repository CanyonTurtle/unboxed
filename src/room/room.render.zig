// Draws the active room's tile grid as flat-colored rects, one fill color
// per TileId -- terrain has no silhouette worth an ASCII-art sprite asset.

const w4 = @import("../wasm4.zig");
const types = @import("room.types.zig");

const TILE_PX: i32 = @intFromFloat(types.TILE_SIZE);
const TILE_PX_U: u32 = @intFromFloat(types.TILE_SIZE);

pub fn draw() void {
    const room = &types.active;
    for (0..types.GRID_H) |ty| {
        for (0..types.GRID_W) |tx| {
            const tile = room.tiles[ty][tx];
            if (tile == .empty) continue;
            w4.DRAW_COLORS.* = switch (tile) {
                .empty => unreachable,
                .ground => 0x0003, // solid color3
                .wall => 0x0004, // solid color4
            };
            w4.Rect(@as(i32, @intCast(tx)) * TILE_PX, @as(i32, @intCast(ty)) * TILE_PX, TILE_PX_U, TILE_PX_U);
        }
    }
}
