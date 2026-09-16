// Draws a pickup item. Each ItemKind gets its own tiny sprite + color;
// adding a new kind means adding one sprite constant and one switch arm.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("item.types.zig");

const COIN_SPRITE = sprite_mod.fromArt(&.{
    ".####.",
    "######",
    "######",
    "######",
    "######",
    ".####.",
});

const HEART_SPRITE = sprite_mod.fromArt(&.{
    ".##.##.",
    "#######",
    "#######",
    ".#####.",
    "..###..",
    "...#...",
});

pub fn draw(item: types.Item) void {
    if (item.collected) return;
    const x: i32 = @intFromFloat(item.x);
    const y: i32 = @intFromFloat(item.y);
    switch (item.kind) {
        .coin => {
            w4.DRAW_COLORS.* = 0x0030; // color2 = palette[2]
            COIN_SPRITE.draw(x, y, false);
        },
        .heart => {
            w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3]
            HEART_SPRITE.draw(x, y, false);
        },
    }
}
