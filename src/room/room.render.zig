// Draws a room's tile grid at an optional pixel offset (for sliding it
// during a transition). Floor, walls, and doors are all white -- silhouette-only.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("room.types.zig");

const TILE_PX: i32 = @intFromFloat(types.TILE_SIZE);
const WHITE: u16 = 0x0020; // color2 = palette[1]

// Grass-tufted top, solid beneath -- floors and platforms read as "ground".
const GROUND_VARIANTS = [_]sprite_mod.Sprite{
    sprite_mod.fromArt(&.{ ".#.#.", "#####", "#####", "#####", "#####" }),
    sprite_mod.fromArt(&.{ "#.#.#", "#####", "#####", "#####", "#####" }),
    sprite_mod.fromArt(&.{ ".#.#.", "#####", "##.##", "#####", "#####" }),
};

// Offset brick coursing -- walls read as "masonry", distinct from ground.
const WALL_VARIANTS = [_]sprite_mod.Sprite{
    sprite_mod.fromArt(&.{ "#####", "##.##", "#####", "#.#.#", "#####" }),
    sprite_mod.fromArt(&.{ "#.#.#", "#####", "##.##", "#####", "#.#.#" }),
};

// A hollow frame -- reads as an actual doorway, not more brick/ground.
const DOOR_SPRITE = sprite_mod.fromArt(&.{
    "#####",
    "#...#",
    "#...#",
    "#...#",
    "#####",
});

// A cheap position hash (not a real PRNG) -- deterministic per tile so the
// pattern never flickers frame to frame, with no need to store a variant.
fn variantIndex(tx: usize, ty: usize, count: u32) u32 {
    var h: u32 = @as(u32, @intCast(tx)) *% 374761393 +% @as(u32, @intCast(ty)) *% 668265263;
    h = (h ^ (h >> 13)) *% 1274126177;
    return (h ^ (h >> 16)) % count;
}

pub fn draw(room: *const types.Room, offset_x: i32, offset_y: i32) void {
    for (0..types.GRID_H) |ty| {
        for (0..types.GRID_W) |tx| {
            const tile = room.tiles[ty][tx];
            if (tile == .empty) continue;
            if (types.isOpenExitTile(@intCast(tx), @intCast(ty))) continue;

            const x = @as(i32, @intCast(tx)) * TILE_PX + offset_x;
            const y = @as(i32, @intCast(ty)) * TILE_PX + offset_y;
            w4.DRAW_COLORS.* = WHITE;

            if (types.spanSideAt(@intCast(tx), @intCast(ty))) |side| {
                if (types.active_door_sides[@intFromEnum(side)]) {
                    DOOR_SPRITE.draw(x, y, false);
                    continue;
                }
            }

            switch (tile) {
                .empty => unreachable,
                .ground => GROUND_VARIANTS[variantIndex(tx, ty, GROUND_VARIANTS.len)].draw(x, y, false),
                .wall => WALL_VARIANTS[variantIndex(tx, ty, WALL_VARIANTS.len)].draw(x, y, false),
            }
        }
    }
}
