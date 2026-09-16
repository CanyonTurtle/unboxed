// Draws one frame: room, then each entity kind back-to-front, then the
// character, then the HUD/game-over overlay -- each *.render.zig call is one line.

const std = @import("std");
const w4 = @import("../wasm4.zig");
const room_render = @import("../room/room.render.zig");
const char_types = @import("../character/character.types.zig");
const char_render = @import("../character/character.render.zig");
const pot_types = @import("../pot/pot.types.zig");
const pot_render = @import("../pot/pot.render.zig");
const item_types = @import("../item/item.types.zig");
const item_render = @import("../item/item.render.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const enemy_render = @import("../enemy/enemy.render.zig");
const state = @import("game.types.zig");

pub fn draw() void {
    room_render.draw();
    for (pot_types.pots) |pot| pot_render.draw(pot);
    for (item_types.items) |item| item_render.draw(item);
    for (enemy_types.enemies) |enemy| enemy_render.draw(enemy);
    char_render.draw(char_types.player);
    drawHud();
    if (state.game.game_over) drawGameOver();
}

fn drawHud() void {
    w4.DRAW_COLORS.* = 0x0004;
    var buf: [24]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "HP {d}  GOLD {d}", .{ char_types.player.hp, char_types.player.score }) catch return;
    w4.Text(line, 2, 2);
}

fn drawGameOver() void {
    w4.DRAW_COLORS.* = 0x0004;
    w4.Text("GAME OVER", 54, 72);
    w4.Text("PRESS X", 60, 84);
}
