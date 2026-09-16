// Spring-mass simulation for one swinging platform: each string is a chain
// of damped-spring-connected point masses ending at the plank, itself one more point.

const collision = @import("../core/core.collision.zig");
const room_types = @import("../room/room.types.zig");
const types = @import("platform.types.zig");

const SPRING_K: f32 = 0.1;
const DAMPING: f32 = 0.85;
const GRAVITY: f32 = 0.12;
const SEGMENT_MASS: f32 = 1.0;
const BODY_MASS: f32 = 2.5;
const RIDER_WEIGHT: f32 = 0.5; // extra downward accel on the plank while ridden
const RIDE_TOLERANCE: f32 = 6; // px of slack allowed between feet and the plank's last-known top

// A hard floor for the plank's sag, independent of tuning -- ride results
// move the player without tile collision, so oversag could drag them into the real floor.
const MAX_BODY_Y: f32 = @as(f32, @floatFromInt(room_types.FLOOR_ROW)) * room_types.TILE_SIZE - types.HEIGHT / 2 - 4;

// Places a fresh platform: anchors `WIDTH` apart at `anchor_y`, hanging
// `hang_len` px down to the plank, segments laid out straight as a start.
pub fn spawn(self: *types.SwingPlatform, left_x: f32, anchor_y: f32, hang_len: f32) void {
    const right_x = left_x + types.WIDTH;
    self.anchor_left = .{ .x = left_x, .y = anchor_y };
    self.anchor_right = .{ .x = right_x, .y = anchor_y };
    self.rest_len = hang_len / @as(f32, @floatFromInt(types.SEGMENTS + 1));
    self.body = .{ .x = left_x + types.WIDTH / 2, .y = anchor_y + hang_len };

    for (&self.left, 0..) |*seg, i| {
        const t = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(types.SEGMENTS + 1));
        seg.* = .{ .x = left_x, .y = anchor_y + hang_len * t };
    }
    for (&self.right, 0..) |*seg, i| {
        const t = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(types.SEGMENTS + 1));
        seg.* = .{ .x = right_x, .y = anchor_y + hang_len * t };
    }
    self.active = true;
}

const Force = struct { fx: f32, fy: f32 };

fn springForce(px: f32, py: f32, tx: f32, ty: f32, rest_len: f32) Force {
    const dx = tx - px;
    const dy = ty - py;
    const dist = @sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return .{ .fx = 0, .fy = 0 };
    const stretch = (dist - rest_len) * SPRING_K;
    return .{ .fx = (dx / dist) * stretch, .fy = (dy / dist) * stretch };
}

fn stepPoint(p: *types.Point, force: Force, mass: f32, extra_gravity: f32) void {
    p.vel_x = (p.vel_x + force.fx / mass) * DAMPING;
    p.vel_y = (p.vel_y + force.fy / mass + GRAVITY + extra_gravity) * DAMPING;
    p.x += p.vel_x;
    p.y += p.vel_y;
}

// One string's segments, pulled toward the anchor above and the plank's
// attachment point below (each neighbor's start-of-frame position).
fn stepString(anchor: types.Point, segments: *[types.SEGMENTS]types.Point, attach_x: f32, attach_y: f32, rest_len: f32) void {
    var force: [types.SEGMENTS]Force = undefined;
    for (0..types.SEGMENTS) |i| {
        const above_x = if (i == 0) anchor.x else segments[i - 1].x;
        const above_y = if (i == 0) anchor.y else segments[i - 1].y;
        const below_x = if (i == types.SEGMENTS - 1) attach_x else segments[i + 1].x;
        const below_y = if (i == types.SEGMENTS - 1) attach_y else segments[i + 1].y;
        const a = springForce(segments[i].x, segments[i].y, above_x, above_y, rest_len);
        const b = springForce(segments[i].x, segments[i].y, below_x, below_y, rest_len);
        force[i] = .{ .fx = a.fx + b.fx, .fy = a.fy + b.fy };
    }
    for (0..types.SEGMENTS) |i| stepPoint(&segments[i], force[i], SEGMENT_MASS, 0);
}

fn stepBody(self: *types.SwingPlatform, extra_weight: f32) void {
    const half_w = types.WIDTH / 2;
    const l = springForce(self.body.x - half_w, self.body.y, self.left[types.SEGMENTS - 1].x, self.left[types.SEGMENTS - 1].y, self.rest_len);
    const r = springForce(self.body.x + half_w, self.body.y, self.right[types.SEGMENTS - 1].x, self.right[types.SEGMENTS - 1].y, self.rest_len);
    stepPoint(&self.body, .{ .fx = l.fx + r.fx, .fy = l.fy + r.fy }, BODY_MASS, extra_weight);

    if (self.body.y > MAX_BODY_Y) {
        self.body.y = MAX_BODY_Y;
        self.body.vel_y = @min(self.body.vel_y, 0);
    }
}

// Advances the platform one frame and reports whether the player (a plain
// box + vertical speed, never character.types) is riding it -- see RideResult.
pub fn update(self: *types.SwingPlatform, player_box: collision.Rect, player_vel_y: f32) types.RideResult {
    if (!self.active) return .{};

    const half_w = types.WIDTH / 2;
    const half_h = types.HEIGHT / 2;
    const prev_top_y = self.body.y - half_h;
    const overlaps_x = player_box.x + player_box.w > self.body.x - half_w and player_box.x < self.body.x + half_w;
    const feet_y = player_box.y + player_box.h;
    const riding = overlaps_x and player_vel_y >= -0.01 and @abs(feet_y - prev_top_y) <= RIDE_TOLERANCE;

    const prev_body_x = self.body.x;
    stepString(self.anchor_left, &self.left, self.body.x - half_w, self.body.y, self.rest_len);
    stepString(self.anchor_right, &self.right, self.body.x + half_w, self.body.y, self.rest_len);
    stepBody(self, if (riding) RIDER_WEIGHT else 0);

    if (!riding) return .{};
    return .{ .riding = true, .top_y = self.body.y - half_h, .delta_x = self.body.x - prev_body_x };
}

const testing = @import("std").testing;

test "spawn lays out both strings straight down from their anchors to the plank" {
    var p: types.SwingPlatform = .{};
    spawn(&p, 20, 10, 40);
    try testing.expectEqual(@as(f32, 20), p.anchor_left.x);
    try testing.expectEqual(@as(f32, 20 + types.WIDTH), p.anchor_right.x);
    try testing.expectEqual(@as(f32, 50), p.body.y); // 10 + 40
    try testing.expect(p.left[0].y > p.anchor_left.y and p.left[0].y < p.body.y);
}

test "an unridden platform settles instead of oscillating forever or blowing up" {
    var p: types.SwingPlatform = .{};
    spawn(&p, 20, 10, 40);
    const far_away = collision.Rect{ .x = -1000, .y = -1000, .w = 1, .h = 1 };

    var i: u32 = 0;
    while (i < 400) : (i += 1) _ = update(&p, far_away, 0);

    // Bounded and finite -- a blown-up simulation would fail this outright.
    try testing.expect(@abs(p.body.y) < 1000);
    try testing.expect(p.body.y == p.body.y); // false for NaN

    // Settled: still moving barely, if at all.
    try testing.expect(@abs(p.body.vel_y) < 0.05);
}

test "update reports riding when the player's feet sit on the plank" {
    var p: types.SwingPlatform = .{};
    spawn(&p, 20, 10, 40);
    const player_box = collision.Rect{ .x = p.body.x - 2, .y = p.body.y - types.HEIGHT / 2 - 8, .w = 8, .h = 8 };

    const result = update(&p, player_box, 0);

    try testing.expect(result.riding);
}

test "update does not report riding when the player is far from the plank" {
    var p: types.SwingPlatform = .{};
    spawn(&p, 20, 10, 40);
    const far_away = collision.Rect{ .x = -1000, .y = -1000, .w = 8, .h = 8 };

    const result = update(&p, far_away, 0);

    try testing.expect(!result.riding);
}

test "a long-hanging, sustained-ridden platform never sags into the room's floor" {
    var p: types.SwingPlatform = .{};
    spawn(&p, 20, 10, 100); // the longest hang map.sim ever generates

    var i: u32 = 0;
    while (i < 600) : (i += 1) {
        const rider_box = collision.Rect{ .x = p.body.x - 2, .y = p.body.y - types.HEIGHT / 2 - 8, .w = 8, .h = 8 };
        _ = update(&p, rider_box, 0);
    }

    try testing.expect(p.body.y <= MAX_BODY_Y);
}

test "a ridden platform sags lower than an unridden one after the same time" {
    var ridden: types.SwingPlatform = .{};
    var bare: types.SwingPlatform = .{};
    spawn(&ridden, 20, 10, 40);
    spawn(&bare, 20, 10, 40);

    var i: u32 = 0;
    while (i < 30) : (i += 1) {
        const rider_box = collision.Rect{ .x = ridden.body.x - 2, .y = ridden.body.y - types.HEIGHT / 2 - 8, .w = 8, .h = 8 };
        _ = update(&ridden, rider_box, 0);
        _ = update(&bare, collision.Rect{ .x = -1000, .y = -1000, .w = 1, .h = 1 }, 0);
    }

    try testing.expect(ridden.body.y > bare.body.y);
}
