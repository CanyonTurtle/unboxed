// A pickup item -- pure data; see item.sim.zig for the pickup rule. A new
// kind is one enum variant here plus one switch arm each in sim/render.

const collision = @import("../core/core.collision.zig");

pub const SIZE: f32 = 6;
pub const MAX_COUNT = 6;

pub const ItemKind = enum { coin, heart };

pub const Item = struct {
    x: f32 = 0,
    y: f32 = 0,
    kind: ItemKind = .coin,
    // Starts true: a slot is "empty" until game.sim reveals it from a pot,
    // reusing this flag rather than a separate active/inactive field.
    collected: bool = true,

    pub fn aabb(self: Item) collision.Rect {
        return .{ .x = self.x, .y = self.y, .w = SIZE, .h = SIZE };
    }
};

pub var items: [MAX_COUNT]Item = [_]Item{.{}} ** MAX_COUNT;
