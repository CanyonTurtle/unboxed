// Character movement: a tank that never stops, auto-driving a gripped
// surface, corner-turning at its end. Jump leaps off; mid-air it swirls.

const std = @import("std");
const w4 = @import("../wasm4.zig");
const input = @import("../core/core.input.zig");
const gravity = @import("../core/core.gravity.zig");
const collision = @import("../core/core.collision.zig");
const room_types = @import("../room/room.types.zig");
const types = @import("character.types.zig");

const FORWARD_SPEED: f32 = 1.1; // constant drive speed along whatever surface is gripped
const GRIP_SPEED: f32 = 0.6; // constant push into the gripped surface, keeping it snapped there
const LEAP_SPEED: f32 = 4.2; // magnitude of a leap off the current surface, direction below
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
fn travelSign(surface: types.Surface, clockwise: bool) f32 {
    const cw_sign: f32 = switch (surface) {
        .floor => -1,
        .left_wall => -1,
        .ceiling => 1,
        .right_wall => 1,
    };
    return if (clockwise) cw_sign else -cw_sign;
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

// Which two buttons steer this surface's travel direction -- the other two
// arrow buttons do nothing, since travel only ever runs along one axis.
fn steerButtons(surface: types.Surface) struct { cw: u8, ccw: u8 } {
    return switch (surface) {
        .floor => .{ .cw = w4.BUTTON_LEFT, .ccw = w4.BUTTON_RIGHT },
        .ceiling => .{ .cw = w4.BUTTON_RIGHT, .ccw = w4.BUTTON_LEFT },
        .left_wall => .{ .cw = w4.BUTTON_UP, .ccw = w4.BUTTON_DOWN },
        .right_wall => .{ .cw = w4.BUTTON_DOWN, .ccw = w4.BUTTON_UP },
    };
}

pub fn update(self: *types.Character, gamepad: u8, prev_gamepad: u8) void {
    const stunned = self.hit_stun_timer > 0;
    const surface_before = self.surface;

    if (surface_before) |surface| {
        if (!stunned) {
            const buttons = steerButtons(surface);
            if (input.held(gamepad, buttons.cw)) self.clockwise = true;
            if (input.held(gamepad, buttons.ccw)) self.clockwise = false;
        }
        const travel = FORWARD_SPEED * travelSign(surface, self.clockwise);
        const grip = GRIP_SPEED * gripSign(surface);
        if (gripAxisIsX(surface)) {
            self.vel_x = grip;
            self.vel_y = travel;
        } else {
            self.vel_x = travel;
            self.vel_y = grip;
        }
        if (!gripAxisIsX(surface)) self.facing_right = travel > 0;

        // Leaps away from the surface (local "up"), carrying travel speed
        // into the arc -- one button for every surface, ground jump included.
        if (!stunned and input.justPressed(gamepad, prev_gamepad, w4.BUTTON_1)) {
            const leap = -gripSign(surface) * LEAP_SPEED;
            if (gripAxisIsX(surface)) {
                self.vel_x = leap;
                self.vel_y = travel;
            } else {
                self.vel_x = travel;
                self.vel_y = leap;
            }
            self.surface = null;
        }
    } else {
        gravity.apply(&self.vel_y, false);
        if (!stunned and input.justPressed(gamepad, prev_gamepad, w4.BUTTON_1)) {
            self.swing_timer = types.SWING_FRAMES;
        }
    }

    const vel_x_before_collision = self.vel_x;
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
        // Airborne (leaping or falling) -- landing on anything reattaches,
        // the side it lands on deciding which surface.
        if (result.on_ground) {
            self.surface = .floor;
        } else if (result.hit_wall) {
            self.surface = if (vel_x_before_collision > 0) .right_wall else if (vel_x_before_collision < 0) .left_wall else null;
        }
    }

    if (surface_before == null and self.surface != null) self.squash_timer = SQUASH_FRAMES;
    if (self.squash_timer > 0) self.squash_timer -= 1;
    if (self.surface != null) self.drive_anim +%= 1;

    if (self.swing_timer > 0) self.swing_timer -= 1;
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

test "on the floor, the tank drives left with no input at all -- it never idles" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true };
    const start_x = c.x;
    update(&c, 0, 0);
    try testing.expect(c.x < start_x);
    try testing.expectEqual(types.Surface.floor, c.surface.?);
}

test "steering the opposite way reverses travel direction" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true };
    update(&c, w4.BUTTON_RIGHT, 0); // ccw button on the floor -- reverses it
    try testing.expect(!c.clockwise);
    const x_after_reverse = c.x;
    update(&c, 0, 0);
    try testing.expect(c.x > x_after_reverse);
}

test "the jump button leaps off the current surface, and a second press mid-air swirls" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor };
    update(&c, w4.BUTTON_1, 0);
    try testing.expect(c.surface == null);
    try testing.expect(c.vel_y < 0); // leapt upward, away from the floor

    update(&c, w4.BUTTON_1, 0);
    try testing.expect(c.swing_timer > 0);
}

test "landing back on a surface starts the squash timer" {
    room_types.active = .{};
    room_types.active.tiles[10][6] = .ground;
    var c = types.Character{ .x = 30, .y = 42, .surface = null, .vel_y = 10 };
    update(&c, 0, 0);
    try testing.expectEqual(types.Surface.floor, c.surface.?);
    try testing.expect(c.squash_timer > 0);
}

test "hit stun suppresses steering until it expires" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground;
    var c = types.Character{ .x = 60, .y = 50 - types.HEIGHT, .surface = .floor, .clockwise = true, .hit_stun_timer = 1 };
    update(&c, w4.BUTTON_RIGHT, 0); // still stunned this frame -- steering ignored
    try testing.expect(c.clockwise);
    try testing.expectEqual(@as(u16, 0), c.hit_stun_timer);

    update(&c, w4.BUTTON_RIGHT, 0); // stun has expired -- steering works now
    try testing.expect(!c.clockwise);
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
        update(&c, 0, 0);
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
