// Draws every live particle as a single bright pixel -- cheap enough that
// spawning a whole burst never costs more than a handful of w4.Rect calls.

const w4 = @import("../wasm4.zig");
const types = @import("particle.types.zig");

pub fn draw(offset_x: i32, offset_y: i32) void {
    w4.DRAW_COLORS.* = 0x0040; // color2 = palette[3] (yellow)
    for (types.particles) |p| {
        if (p.life == 0) continue;
        const x: i32 = @intFromFloat(p.x);
        const y: i32 = @intFromFloat(p.y);
        w4.Rect(x + offset_x, y + offset_y, 1, 1);
    }
}
