// Shared sprite type: sprites are ASCII art defined right in code (see each
// entity's *.render.zig), not imported from an image file via a build step.

const w4 = @import("../wasm4.zig");

// One 1BPP sprite: `pixels` is packed to WASM4's real 1BPP layout so
// drawing goes through the actual w4.Blit host call.
pub const Sprite = struct {
    width: u32,
    height: u32,
    pixels: []const u8,

    pub fn draw(self: Sprite, x: i32, y: i32, flip_x: bool) void {
        var flags: u32 = w4.BLIT_1BPP;
        if (flip_x) flags |= w4.BLIT_FLIP_X;
        w4.Blit(self.pixels.ptr, x, y, self.width, self.height, flags);
    }
};

// Packs ASCII art into a Sprite at comptime: '#' is opaque, anything else
// ('.') is transparent. `rows` must be comptime-known -- top-level `const` art only.
pub fn fromArt(comptime rows: []const []const u8) Sprite {
    const height = rows.len;
    const width = rows[0].len;
    const total_bits = width * height;
    const total_bytes = (total_bits + 7) / 8;

    const packed_pixels = comptime blk: {
        var pixels: [total_bytes]u8 = [_]u8{0} ** total_bytes;
        for (rows, 0..) |row, ry| {
            if (row.len != width) @compileError("sprite rows must all be the same length");
            for (row, 0..) |ch, rx| {
                if (ch == '#') {
                    const bit_index = ry * width + rx;
                    const byte_index = bit_index / 8;
                    const shift: u3 = @intCast(7 - (bit_index % 8));
                    pixels[byte_index] |= (@as(u8, 1) << shift);
                }
            }
        }
        break :blk pixels;
    };

    return .{ .width = width, .height = height, .pixels = &packed_pixels };
}

test "fromArt packs a 2x2 checkerboard into the expected MSB-first bits" {
    const testing = @import("std").testing;
    const sprite = fromArt(&.{
        "#.",
        ".#",
    });
    try testing.expectEqual(@as(u32, 2), sprite.width);
    try testing.expectEqual(@as(u32, 2), sprite.height);
    // Row 0 "#." -> bits 1,0; row 1 ".#" -> bits 0,1 => byte 0b1001_0000.
    try testing.expectEqual(@as(u8, 0b1001_0000), sprite.pixels[0]);
}

test "fromArt handles an all-transparent sprite" {
    const testing = @import("std").testing;
    const sprite = fromArt(&.{
        "..",
        "..",
    });
    try testing.expectEqual(@as(u8, 0), sprite.pixels[0]);
}
