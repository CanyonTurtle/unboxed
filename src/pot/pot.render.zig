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

pub fn draw(pot: types.Pot) void {
    if (pot.broken) return;
    w4.DRAW_COLORS.* = 0x0030; // color2 = palette[2] (see character.render's DRAW_COLORS comment)
    SPRITE.draw(@intFromFloat(pot.x), @intFromFloat(pot.y), false);
}
