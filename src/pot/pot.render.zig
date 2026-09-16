// Draws an intact pot; a broken one simply stops drawing (game.sim spawns
// an item in its place -- no "shatter" animation in this prototype).

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("pot.types.zig");

const SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    "########",
    "##....##",
    "########",
    ".######.",
    "..####..",
    "........",
});

pub fn draw(pot: types.Pot, offset_x: i32, offset_y: i32) void {
    if (pot.broken) return;
    w4.DRAW_COLORS.* = 0x0020; // color2 = palette[1] (white)
    SPRITE.draw(@as(i32, @intFromFloat(pot.x)) + offset_x, @as(i32, @intFromFloat(pot.y)) + offset_y, false);
}
