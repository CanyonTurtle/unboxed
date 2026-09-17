// Character movement: one button, no gravity. Hold to rev up (Character.
// speed); a tap turns around, a real hold launches a straight-line float on release.

const std = @import("std");
const w4 = @import("../wasm4.zig");
const input = @import("../core/core.input.zig");
const collision = @import("../core/core.collision.zig");
const room_types = @import("../room/room.types.zig");
const types = @import("character.types.zig");

const MAX_SPEED: f32 = 2.0; // top drive speed, reached by holding the button
const ACCEL: f32 = 0.09; // speed gained per frame held -- a real "revving up"
// Below this much charge, releasing just turns the tank around in place
// instead of launching -- a tap steers, a hold commits to a leap.
const TURN_THRESHOLD: f32 = 0.3;
const GRIP_SPEED: f32 = 0.6; // constant push into the gripped surface, keeping it snapped there
// Releasing launches leap_base + speed*leap_scale: a light hold still
// hops, a fully-revved release launches further. Wall leaps stay weaker overall.
const LEAP_BASE: f32 = 2.0;
const LEAP_SCALE: f32 = 1.4;
const WALL_LEAP_BASE: f32 = 1.0;
const WALL_LEAP_SCALE: f32 = 0.6;
const DAMAGE_KNOCKBACK: f32 = 2.0;
const INVULN_FRAMES: u16 = 45;
const SQUASH_FRAMES: u8 = 7;
const HIT_STUN_FRAMES: u16 = 12;

// True for the two wall surfaces, where "into the surface" is a horizontal
// push and travel runs vertically -- false for floor/ceiling, the reverse.
fn gripAxisIsX(surface: types.Surface) bool {
    return surface == .left_wall or surface == .right_wall;
}

// Which way, along the grip axis, points *into* the surface being gripped.
fn gripSign(surface: types.Surface) f32 {
    return switch (surface) {
        .floor => 1,
        .ceiling => -1,
        .left_wall => -1,
        .right_wall => 1,
    };
}

// Which way is "clockwise" along the travel axis for this surface -- floor
// left, left_wall up, ceiling right, right_wall down -- so cw traces the perimeter.
fn cwSign(surface: types.Surface) f32 {
    return switch (surface) {
        .floor => -1,
        .left_wall => -1,
        .ceiling => 1,
        .right_wall => 1,
    };
}

fn travelSign(surface: types.Surface, clockwise: bool) f32 {
    const sign = cwSign(surface);
    return if (clockwise) sign else -sign;
}

// Which `clockwise` reproduces this travel-axis velocity on this surface --
// resyncs steering from momentum on landing; it otherwise only changes via a tap-turn.
fn clockwiseFor(surface: types.Surface, travel_velocity: f32) bool {
    return (travel_velocity < 0) == (cwSign(surface) < 0);
}

// The next surface reached by traveling off the end of this one, in the
// same rotational sense -- the perimeter cycle floor/left_wall/ceiling/right_wall.
fn nextSurface(surface: types.Surface, clockwise: bool) types.Surface {
    return switch (surface) {
        .floor => if (clockwise) .left_wall else .right_wall,
        .left_wall => if (clockwise) .ceiling else .floor,
        .ceiling => if (clockwise) .right_wall else .left_wall,
        .right_wall => if (clockwise) .floor else .ceiling,
    };
}

pub fn update(self: *types.Character, gamepad: u8, prev_gamepad: u8) void {
    const stunned = self.hit_stun_timer > 0;
    const surface_before = self.surface;

    if (surface_before) |surface| {
        const throttling = input.held(gamepad, w4.BUTTON_1);
        const was_throttling = input.held(prev_gamepad, w4.BUTTON_1);
        const releasing = !stunned and was_throttling and !throttling;

        if (!stunned and !releasing and throttling) {
            self.speed = @min(self.speed + ACCEL, MAX_SPEED);
        }

        const travel = self.speed * travelSign(surface, self.clockwise);
        const grip = GRIP_SPEED * gripSign(surface);
        if (gripAxisIsX(surface)) {
            self.vel_x = grip;
            self.vel_y = travel;
        } else {
            self.vel_x = travel;
            self.vel_y = grip;
        }
        if (!gripAxisIsX(surface)) self.facing_right = travel > 0;

        if (releasing) {
            if (self.speed < TURN_THRESHOLD) {
                // Too little charge to launch -- read it as just a tap, turning around in place.
                self.clockwise = !self.clockwise;
                if (!gripAxisIsX(surface)) self.facing_right = travelSign(surface, self.clockwise) > 0;
            } else {
                const leap_base = if (gripAxisIsX(surface)) WALL_LEAP_BASE else LEAP_BASE;
                const leap_scale = if (gripAxisIsX(surface)) WALL_LEAP_SCALE else LEAP_SCALE;
                const leap = -gripSign(surface) * (leap_base + self.speed * leap_scale);
                if (gripAxisIsX(surface)) {
                    self.vel_x = leap;
                } else {
                    self.vel_y = leap;
                }
                // Whichever way it's now actually moving horizontally, face
                // that way -- otherwise a wall leap can land facing backwards.
                self.facing_right = self.vel_x > 0;
                self.surface = null;
            }
            self.speed = 0;
        }
    }
    // No else, no gravity: while airborne, vel_x/vel_y are left exactly as
    // the leap set them -- a straight float until it runs into something.

    const vel_x_before_collision = self.vel_x;
    const vel_y_before_collision = self.vel_y;
    const tiles = collision.TileQuery{ .tile_size = room_types.TILE_SIZE, .isSolid = &room_types.isSolid };
    const result = collision.moveAndCollide(&self.x, &self.y, types.WIDTH, types.HEIGHT, &self.vel_x, &self.vel_y, tiles);

    if (surface_before != null and self.surface != null) {
        // Still riding the surface we started the frame on (didn't just
        // leap) -- see if travel reached its end (a corner) or grip broke.
        const surface = surface_before.?;
        // hit_wall alone is already direction-symmetric; on_ground/hit_ceiling
        // together give the same for y, since neither alone covers both ways.
        const x_blocked = result.hit_wall;
        const y_blocked = result.on_ground or result.hit_ceiling;
        const travel_blocked = if (gripAxisIsX(surface)) y_blocked else x_blocked;
        const grip_intact = if (gripAxisIsX(surface)) x_blocked else y_blocked;
        if (travel_blocked) {
            self.surface = nextSurface(surface, self.clockwise);
        } else if (!grip_intact) {
            self.surface = null; // drove off the edge -- fall until something catches it
        }
    } else if (self.surface == null) {
        // Airborne -- landing reattaches by which side it hit, and resyncs
        // `clockwise` to momentum, not whichever way it faced before leaping.
        if (result.on_ground) {
            self.surface = .floor;
            if (vel_x_before_collision != 0) self.clockwise = clockwiseFor(.floor, vel_x_before_collision);
        } else if (result.hit_wall) {
            self.surface = if (vel_x_before_collision > 0) .right_wall else if (vel_x_before_collision < 0) .left_wall else null;
            if (self.surface) |landed| {
                if (vel_y_before_collision != 0) self.clockwise = clockwiseFor(landed, vel_y_before_collision);
            }
        }
    }

    if (surface_before == null and self.surface != null) self.squash_timer = SQUASH_FRAMES;
    if (self.squash_timer > 0) self.squash_timer -= 1;
    if (self.surface != null) self.drive_anim +%= 1;

    if (self.invuln_timer > 0) self.invuln_timer -= 1;
    if (self.hit_stun_timer > 0) self.hit_stun_timer -= 1;
}

// Applies contact damage and knockback, knocks the character airborne, and
// starts hit stun. A no-op while still invulnerable from a previous hit.
pub fn takeDamage(self: *types.Character, amount: i32, from_x: f32) void {
    if (self.invuln_timer > 0) return;
    self.hp = @max(0, self.hp - amount);
    self.vel_x = if (self.x < from_x) -DAMAGE_KNOCKBACK else DAMAGE_KNOCKBACK;
    self.vel_y = -1.5;
    self.surface = null;
    self.invuln_timer = INVULN_FRAMES;
    self.hit_stun_timer = HIT_STUN_FRAMES;
}

const testing = std.testing;

test "holding the button accelerates the tank's speed" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true };
    update(&c, w4.BUTTON_1, 0);
    const speed_after_one = c.speed;
    try testing.expect(speed_after_one > 0);
    update(&c, w4.BUTTON_1, w4.BUTTON_1);
    try testing.expect(c.speed > speed_after_one); // keeps revving up
}

test "with no input, the tank sits still" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true };
    update(&c, 0, 0);
    try testing.expectEqual(@as(f32, 0), c.speed);
    const x_after = c.x;
    update(&c, 0, 0);
    try testing.expectEqual(x_after, c.x);
}

test "a quick tap below the charge threshold just turns the tank around" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true };
    update(&c, w4.BUTTON_1, 0); // press -- one frame of charge, well under the threshold
    update(&c, 0, w4.BUTTON_1); // release immediately
    try testing.expectEqual(types.Surface.floor, c.surface.?); // no leap -- still gripped
    try testing.expect(!c.clockwise); // turned around instead
    try testing.expectEqual(@as(f32, 0), c.speed);
}

test "releasing after real charge leaps off the surface and floats away" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true };
    var i: u32 = 0;
    while (i < 10) : (i += 1) update(&c, w4.BUTTON_1, 0); // well past TURN_THRESHOLD
    update(&c, 0, w4.BUTTON_1); // release
    try testing.expect(c.surface == null);
    try testing.expect(c.vel_y < 0); // leapt upward, away from the floor
    try testing.expectEqual(@as(f32, 0), c.speed);

    const vy = c.vel_y;
    update(&c, 0, 0); // airborne, no input -- no gravity means vel_y is untouched
    try testing.expectEqual(vy, c.vel_y);
}

test "releasing while climbing a wall floats away in a straight line and eventually lands" {
    room_types.active = .{};
    for (0..room_types.GRID_H) |ty| room_types.active.tiles[ty][5] = .wall; // left wall, full height
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[20][tx] = .ground; // full floor row
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[3][tx] = .wall; // ceiling
    for (0..room_types.GRID_H) |ty| room_types.active.tiles[ty][25] = .wall; // right wall

    var c = types.Character{ .x = 30, .y = 40, .surface = .left_wall, .clockwise = false }; // climbing down
    var i: u32 = 0;
    while (i < 15) : (i += 1) update(&c, w4.BUTTON_1, 0); // hold to build real charge
    try testing.expect(c.speed > 0);

    update(&c, 0, w4.BUTTON_1); // release
    try testing.expect(c.surface == null);
    try testing.expect(c.vel_x > 0); // away from the wall
    try testing.expectEqual(@as(f32, 0), c.speed);

    const vy = c.vel_y;
    i = 0;
    while (i < 200 and c.surface == null) : (i += 1) {
        try testing.expectEqual(vy, c.vel_y); // no gravity -- a straight float, not an arc
        update(&c, 0, 0);
    }
    try testing.expect(c.surface != null); // it eventually runs into the enclosing room
    try testing.expectEqual(@as(f32, 0), c.speed); // sits still until steered again
}

test "landing while drifting resyncs clockwise to match the actual drift direction" {
    room_types.active = .{};
    for (1..31) |tx| room_types.active.tiles[10][tx] = .ground; // a full floor row, well below the start
    var c = types.Character{ .x = 40, .y = 30, .surface = null, .vel_x = -1.5, .vel_y = 0.6, .clockwise = false };
    var i: u32 = 0;
    while (i < 30 and c.surface == null) : (i += 1) update(&c, 0, 0);
    try testing.expectEqual(types.Surface.floor, c.surface.?);
    try testing.expect(c.clockwise); // drifting left = clockwise on the floor, regardless of the old value
}

test "landing back on a surface starts the squash timer" {
    room_types.active = .{};
    room_types.active.tiles[10][6] = .ground;
    var c = types.Character{ .x = 30, .y = 42, .surface = null, .vel_y = 10 };
    update(&c, 0, 0);
    try testing.expectEqual(types.Surface.floor, c.surface.?);
    try testing.expect(c.squash_timer > 0);
}

test "hit stun suppresses throttle input until it expires" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true, .hit_stun_timer = 1 };
    update(&c, w4.BUTTON_1, 0); // still stunned this frame -- throttle ignored
    try testing.expectEqual(@as(f32, 0), c.speed);
    try testing.expectEqual(@as(u16, 0), c.hit_stun_timer);

    update(&c, w4.BUTTON_1, 0); // stun has expired -- throttle works now
    try testing.expect(c.speed > 0);
}

test "takeDamage knocks the character airborne, applies knockback, and starts invuln/stun" {
    var c = types.Character{ .x = 20, .hp = types.BASE_MAX_HP, .surface = .floor };
    takeDamage(&c, 1, 30); // hazard to the right -> knocked left
    try testing.expectEqual(types.BASE_MAX_HP - 1, c.hp);
    try testing.expect(c.vel_x < 0);
    try testing.expect(c.surface == null);
    try testing.expect(c.invuln_timer > 0);
    try testing.expect(c.hit_stun_timer > 0);
}

test "takeDamage is a no-op while invulnerable" {
    var c = types.Character{ .hp = types.BASE_MAX_HP, .invuln_timer = 10 };
    takeDamage(&c, 1, 0);
    try testing.expectEqual(types.BASE_MAX_HP, c.hp);
}

test "driving clockwise crawls the whole inside perimeter: floor -> wall -> ceiling -> wall -> floor" {
    room_types.active = .{};
    for (6..15) |tx| room_types.active.tiles[20][tx] = .ground; // floor
    for (5..21) |ty| room_types.active.tiles[ty][5] = .wall; // left wall
    for (5..21) |ty| room_types.active.tiles[ty][15] = .wall; // right wall
    for (6..15) |tx| room_types.active.tiles[5][tx] = .wall; // ceiling

    var c = types.Character{
        .x = 10 * room_types.TILE_SIZE,
        .y = 20 * room_types.TILE_SIZE - types.HEIGHT,
        .surface = .floor,
        .clockwise = true,
    };
    var seen_left_wall = false;
    var seen_ceiling = false;
    var seen_right_wall = false;
    var back_to_floor = false;
    var i: u32 = 0;
    while (i < 400) : (i += 1) {
        update(&c, w4.BUTTON_1, 0); // held throughout -- speed stays revved through every corner
        if (c.surface) |s| switch (s) {
            .left_wall => seen_left_wall = true,
            .ceiling => seen_ceiling = true,
            .right_wall => seen_right_wall = true,
            .floor => if (seen_right_wall) {
                back_to_floor = true;
            },
        };
        if (back_to_floor) break;
    }
    try testing.expect(seen_left_wall);
    try testing.expect(seen_ceiling);
    try testing.expect(seen_right_wall);
    try testing.expect(back_to_floor);
}
