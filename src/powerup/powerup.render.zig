// Draws a revealed, uncollected powerup. Each PowerupKind gets its own
// sprite + color, same convention as item.render.zig.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("powerup.types.zig");

const EXTRA_HP_SPRITE = sprite_mod.fromArt(&.{
    "..####..",
    ".######.",
    "##.##.##",
    "########",
    "########",
    ".######.",
    "..####..",
    "........",
});

const DOUBLE_JUMP_SPRITE = sprite_mod.fromArt(&.{
    "...##...",
    "..####..",
    ".######.",
    "........",
    "...##...",
    "..####..",
    ".######.",
    "........",
});

pub fn draw(p: types.Powerup) void {
    if (!p.placed or !p.revealed or p.collected) return;
    const x: i32 = @intFromFloat(p.x);
    const y: i32 = @intFromFloat(p.y);
    switch (p.kind) {
        .extra_hp => {
            w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3]
            EXTRA_HP_SPRITE.draw(x, y, false);
        },
        .double_jump => {
            w4.DRAW_COLORS.* = 0x0020; // color2 = palette[1]
            DOUBLE_JUMP_SPRITE.draw(x, y, false);
        },
    }
}
