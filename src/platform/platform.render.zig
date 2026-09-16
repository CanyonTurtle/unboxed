// Draws a swinging platform: each string as connected line segments (a
// real rope shape falls out of just connecting the dots), plank as a sprite.

const w4 = @import("../wasm4.zig");
const sprite_mod = @import("../core/core.sprite.zig");
const types = @import("platform.types.zig");

const PLANK_SPRITE = sprite_mod.fromArt(&.{
    "###.###.###.###",
    "###############",
    "###############",
    "###.###.###.###",
});

fn drawString(anchor: types.Point, segments: [types.SEGMENTS]types.Point, attach_x: f32, attach_y: f32) void {
    var prev_x: i32 = @intFromFloat(anchor.x);
    var prev_y: i32 = @intFromFloat(anchor.y);
    for (segments) |seg| {
        const x: i32 = @intFromFloat(seg.x);
        const y: i32 = @intFromFloat(seg.y);
        w4.Line(prev_x, prev_y, x, y);
        prev_x = x;
        prev_y = y;
    }
    w4.Line(prev_x, prev_y, @intFromFloat(attach_x), @intFromFloat(attach_y));
}

pub fn draw(p: types.SwingPlatform) void {
    if (!p.active) return;
    const half_w = types.WIDTH / 2;

    w4.DRAW_COLORS.* = 0x0004; // line() strokes with color1 = palette[3]
    drawString(p.anchor_left, p.left, p.body.x - half_w, p.body.y);
    drawString(p.anchor_right, p.right, p.body.x + half_w, p.body.y);

    w4.DRAW_COLORS.* = 0x0030; // color2 = palette[2], matching ground tiles
    PLANK_SPRITE.draw(@intFromFloat(p.body.x - half_w), @intFromFloat(p.body.y - types.HEIGHT / 2), false);
}
