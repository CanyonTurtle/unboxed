// Draws the active room's tile grid. Each solid TileId has a small rotation
// of 5x5 ASCII-art variants (core.sprite.fromArt), picked per tile position.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("room.types.zig");

const TILE_PX: i32 = @intFromFloat(types.TILE_SIZE);

const GROUND_VARIANTS = [_]sprite_mod.Sprite{
    sprite_mod.fromArt(&.{ "#####", "#####", "##.##", "#####", "#####" }),
    sprite_mod.fromArt(&.{ "#####", "##.##", "#####", "##.##", "#####" }),
    sprite_mod.fromArt(&.{ "#####", "#.#.#", "#####", "#.#.#", "#####" }),
};

const WALL_VARIANTS = [_]sprite_mod.Sprite{
    sprite_mod.fromArt(&.{ "#####", "#####", "#####", "#####", "#####" }),
    sprite_mod.fromArt(&.{ "#####", "##.##", "#####", "##.##", "#####" }),
};

// A visibly different pattern (mostly gaps, not a solid fill) so a
// room's diggable spot never looks like ordinary permanent wall.
const DIGGABLE_SPRITE = sprite_mod.fromArt(&.{
    "#...#",
    ".#.#.",
    "..#..",
    ".#.#.",
    "#...#",
});

// A cheap position hash (not a real PRNG) -- deterministic per tile so the
// pattern never flickers frame to frame, with no need to store a variant.
fn variantIndex(tx: usize, ty: usize, count: u32) u32 {
    var h: u32 = @as(u32, @intCast(tx)) *% 374761393 +% @as(u32, @intCast(ty)) *% 668265263;
    h = (h ^ (h >> 13)) *% 1274126177;
    return (h ^ (h >> 16)) % count;
}

pub fn draw() void {
    const room = &types.active;
    for (0..types.GRID_H) |ty| {
        for (0..types.GRID_W) |tx| {
            const tile = room.tiles[ty][tx];
            if (tile == .empty) continue;
            if (tile == .wall and types.isOpenExitTile(@intCast(tx), @intCast(ty))) continue;

            const x = @as(i32, @intCast(tx)) * TILE_PX;
            const y = @as(i32, @intCast(ty)) * TILE_PX;
            switch (tile) {
                .empty => unreachable,
                .ground => {
                    w4.DRAW_COLORS.* = 0x0030; // color2 = palette[2]
                    GROUND_VARIANTS[variantIndex(tx, ty, GROUND_VARIANTS.len)].draw(x, y, false);
                },
                .wall => {
                    if (types.spanSideAt(@intCast(tx), @intCast(ty))) |side| {
                        const digging = types.active_dig_ratio[@intFromEnum(side)] > 0;
                        w4.DRAW_COLORS.* = if (digging) 0x0040 else 0x0020; // red while dug, white otherwise
                        DIGGABLE_SPRITE.draw(x, y, false);
                    } else {
                        w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3]
                        WALL_VARIANTS[variantIndex(tx, ty, WALL_VARIANTS.len)].draw(x, y, false);
                    }
                },
            }
        }
    }
}
