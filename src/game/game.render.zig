// Draws one frame: room + entities (two sliding copies mid-transition),
// character, particles, then an opaque HUD bar so status text never blends in.

const std = @import("std");
const w4 = @import("../wasm4.zig");
const room_types = @import("../room/room.types.zig");
const room_render = @import("../room/room.render.zig");
const char_types = @import("../character/character.types.zig");
const char_render = @import("../character/character.render.zig");
const pot_types = @import("../pot/pot.types.zig");
const pot_render = @import("../pot/pot.render.zig");
const item_types = @import("../item/item.types.zig");
const item_render = @import("../item/item.render.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const enemy_render = @import("../enemy/enemy.render.zig");
const powerup_types = @import("../powerup/powerup.types.zig");
const powerup_render = @import("../powerup/powerup.render.zig");
const key_types = @import("../key/key.types.zig");
const key_render = @import("../key/key.render.zig");
const particle_render = @import("../particle/particle.render.zig");
const camera = @import("../core/core.camera.zig");
const map_types = @import("../map/map.types.zig");
const state = @import("game.types.zig");

const SCREEN: i32 = 160;

fn drawRoomEntities(
    room: *const room_types.Room,
    pots: []const pot_types.Pot,
    items: []const item_types.Item,
    enemies: []const enemy_types.Enemy,
    powerup: powerup_types.Powerup,
    key: key_types.Key,
    ox: i32,
    oy: i32,
) void {
    room_render.draw(room, ox, oy);
    for (pots) |pot| pot_render.draw(pot, ox, oy);
    for (items) |item| item_render.draw(item, ox, oy);
    for (enemies) |enemy| enemy_render.draw(enemy, ox, oy);
    powerup_render.draw(powerup, ox, oy);
    key_render.draw(key, ox, oy);
    particle_render.draw(ox, oy);
}

pub fn draw() void {
    if (map_types.transition.active) {
        drawTransition();
    } else {
        drawRoomEntities(&room_types.active, &pot_types.pots, &item_types.items, &enemy_types.enemies, powerup_types.active, key_types.active, 0, 0);
    }
    char_render.draw(char_types.player);
    drawOverlay();
    if (state.game.game_over) drawGameOver();
}

// The outgoing room slides off the far edge while the incoming one slides
// in from the near edge, at the same eased progress driving the player.
fn drawTransition() void {
    const t = map_types.transition;
    const progress = @min(1.0, @as(f32, @floatFromInt(t.frame)) / @as(f32, @floatFromInt(map_types.TRANSITION_FRAMES)));
    const shift: i32 = @intFromFloat(camera.easeOutQuad(progress) * @as(f32, @floatFromInt(SCREEN)));

    var cur_ox: i32 = 0;
    var cur_oy: i32 = 0;
    var next_ox: i32 = 0;
    var next_oy: i32 = 0;
    switch (t.dir) {
        .right => {
            cur_ox = -shift;
            next_ox = SCREEN - shift;
        },
        .left => {
            cur_ox = shift;
            next_ox = shift - SCREEN;
        },
        .down => {
            cur_oy = -shift;
            next_oy = SCREEN - shift;
        },
        .up => unreachable, // never a transition direction
    }

    drawRoomEntities(&room_types.active, &pot_types.pots, &item_types.items, &enemy_types.enemies, powerup_types.active, key_types.active, cur_ox, cur_oy);
    drawRoomEntities(&map_types.next.room, &map_types.next.pots, &map_types.next.items, &map_types.next.enemies, map_types.next.powerup, map_types.next.key, next_ox, next_oy);
}

fn drawOverlay() void {
    w4.DRAW_COLORS.* = 0x0001; // color1 = palette[0] (black) -- opaque, so text never blends in
    w4.Rect(0, 0, w4.SCREEN_SIZE, 10);
    w4.DRAW_COLORS.* = 0x0002; // color1 = palette[1] (white)
    var buf: [24]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "HP{d}/{d} G{d} R{d}", .{
        char_types.player.hp,
        char_types.player.max_hp,
        char_types.player.score,
        map_types.room_index,
    }) catch return;
    w4.Text(line, 2, 2);
}

fn drawGameOver() void {
    w4.DRAW_COLORS.* = 0x0001;
    w4.Rect(40, 64, 80, 32);
    w4.DRAW_COLORS.* = 0x0002;
    w4.Text("GAME OVER", 54, 72);
    w4.Text("PRESS X", 60, 84);
}
