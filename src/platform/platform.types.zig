// A swinging platform: two segmented strings (spring-mass chains) hang
// from fixed ceiling anchors and hold up a rideable plank between them.

const collision = @import("../core/core.collision.zig");

pub const SEGMENTS: u32 = 4;
pub const MAX_COUNT: u32 = 1;
pub const WIDTH: f32 = 15;
pub const HEIGHT: f32 = 4;

pub const Point = struct { x: f32 = 0, y: f32 = 0, vel_x: f32 = 0, vel_y: f32 = 0 };

pub const SwingPlatform = struct {
    active: bool = false,
    anchor_left: Point = .{},
    anchor_right: Point = .{},
    left: [SEGMENTS]Point = [_]Point{.{}} ** SEGMENTS,
    right: [SEGMENTS]Point = [_]Point{.{}} ** SEGMENTS,
    body: Point = .{},
    rest_len: f32 = 1,

    pub fn aabb(self: SwingPlatform) collision.Rect {
        return .{ .x = self.body.x - WIDTH / 2, .y = self.body.y - HEIGHT / 2, .w = WIDTH, .h = HEIGHT };
    }
};

// platform.sim.update reports this instead of touching character.types
// directly -- only game.sim is allowed to know every entity's shape.
pub const RideResult = struct {
    riding: bool = false,
    top_y: f32 = 0,
    delta_x: f32 = 0,
};

pub var platforms: [MAX_COUNT]SwingPlatform = [_]SwingPlatform{.{}} ** MAX_COUNT;
