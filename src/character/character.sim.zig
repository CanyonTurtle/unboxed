// Character movement: reads gamepad input, then leans on core.gravity/
// core.collision for physics -- this file only holds character-specific tuning.

const std = @import("std");
const w4 = @import("../wasm4.zig");
const input = @import("../core/core.input.zig");
const gravity = @import("../core/core.gravity.zig");
const collision = @import("../core/core.collision.zig");
const room_types = @import("../room/room.types.zig");
const types = @import("character.types.zig");

const MOVE_ACCEL: f32 = 0.4;
const MOVE_MAX_SPEED: f32 = 1.6;
const FRICTION: f32 = 0.8;
const JUMP_VELOCITY: f32 = -4.2;
const WALL_JUMP_PUSH: f32 = 2.0;
const INVULN_FRAMES: u16 = 45;
const DAMAGE_KNOCKBACK: f32 = 2.0;
const SQUASH_FRAMES: u8 = 7;
const HIT_STUN_FRAMES: u16 = 12;

pub fn update(self: *types.Character, gamepad: u8, prev_gamepad: u8) void {
    const was_on_ground = self.on_ground;
    // Stunned: knockback still bleeds off via friction, but no input is read
    // at all -- movement, jumping, and swinging all wait for it to expire.
    const stunned = self.hit_stun_timer > 0;
    var moving_left = false;
    var moving_right = false;
    if (!stunned) {
        moving_left = input.held(gamepad, w4.BUTTON_LEFT);
        moving_right = input.held(gamepad, w4.BUTTON_RIGHT);
        if (moving_left) {
            self.vel_x -= MOVE_ACCEL;
            self.facing_right = false;
        } else if (moving_right) {
            self.vel_x += MOVE_ACCEL;
            self.facing_right = true;
        } else {
            self.vel_x *= FRICTION;
        }
    } else {
        self.vel_x *= FRICTION;
    }
    self.vel_x = std.math.clamp(self.vel_x, -MOVE_MAX_SPEED, MOVE_MAX_SPEED);

    gravity.apply(&self.vel_y, self.on_ground);
    // Clinging to a wall slows a fall to a controlled slide, same idea as
    // on_ground gating gravity.apply above -- capped, never sped up.
    if (self.wall_side != 0 and self.vel_y > 0) gravity.applyWallSlide(&self.vel_y);

    // One button, three meanings: a ground jump, a wall jump when clinging,
    // or -- the fallback for any other airborne press -- the swirl attack.
    if (!stunned and input.justPressed(gamepad, prev_gamepad, w4.BUTTON_1)) {
        if (self.on_ground) {
            self.vel_y = JUMP_VELOCITY;
        } else if (self.wall_side != 0) {
            self.vel_y = JUMP_VELOCITY;
            self.vel_x = -@as(f32, @floatFromInt(self.wall_side)) * WALL_JUMP_PUSH;
            self.facing_right = self.wall_side < 0;
            self.wall_side = 0;
        } else {
            self.swing_timer = types.SWING_FRAMES;
        }
    }

    const tiles = collision.TileQuery{ .tile_size = room_types.TILE_SIZE, .isSolid = &room_types.isSolid };
    const result = collision.moveAndCollide(&self.x, &self.y, types.WIDTH, types.HEIGHT, &self.vel_x, &self.vel_y, tiles);
    self.on_ground = result.on_ground;
    if (!was_on_ground and self.on_ground) self.squash_timer = SQUASH_FRAMES;
    if (self.squash_timer > 0) self.squash_timer -= 1;

    // Only "clinging" while airborne and still pressing into the wall that
    // stopped you -- brushing past one on the ground doesn't count.
    self.wall_side = if (!self.on_ground and result.hit_wall and (moving_left or moving_right))
        (if (moving_left) @as(i8, -1) else 1)
    else
        0;

    if (self.swing_timer > 0) self.swing_timer -= 1;

    if (self.invuln_timer > 0) self.invuln_timer -= 1;
    if (self.hit_stun_timer > 0) self.hit_stun_timer -= 1;
}

// Applies contact damage and knockback, and starts hit stun. A no-op
// while still invulnerable from a previous hit.
pub fn takeDamage(self: *types.Character, amount: i32, from_x: f32) void {
    if (self.invuln_timer > 0) return;
    self.hp = @max(0, self.hp - amount);
    self.vel_x = if (self.x < from_x) -DAMAGE_KNOCKBACK else DAMAGE_KNOCKBACK;
    self.vel_y = -1.5;
    self.invuln_timer = INVULN_FRAMES;
    self.hit_stun_timer = HIT_STUN_FRAMES;
}

const testing = std.testing;

test "update moves right on BUTTON_RIGHT and faces that direction" {
    room_types.active = .{};
    room_types.active.tiles[10][5] = .ground; // floor beneath the character
    var c = types.Character{ .x = 32, .y = 72 };
    update(&c, w4.BUTTON_RIGHT, 0);
    try testing.expect(c.vel_x > 0);
    try testing.expect(c.facing_right);
}

test "update only allows a jump while on_ground" {
    room_types.active = .{};
    var c = types.Character{ .x = 32, .y = 80, .on_ground = false };
    update(&c, w4.BUTTON_1, 0);
    try testing.expect(c.vel_y != JUMP_VELOCITY);

    c = types.Character{ .x = 32, .y = 80, .on_ground = true };
    update(&c, w4.BUTTON_1, 0);
    try testing.expectEqual(JUMP_VELOCITY, c.vel_y);
}

test "takeDamage reduces hp, applies knockback, and starts invulnerability and hit stun" {
    var c = types.Character{ .x = 20, .hp = types.BASE_MAX_HP };
    takeDamage(&c, 1, 30); // hazard to the right -> knocked left
    try testing.expectEqual(types.BASE_MAX_HP - 1, c.hp);
    try testing.expect(c.vel_x < 0);
    try testing.expect(c.invuln_timer > 0);
    try testing.expect(c.hit_stun_timer > 0);
}

test "hit stun suppresses movement and jump input until it expires" {
    room_types.active = .{};
    for (0..room_types.GRID_W) |tx| room_types.active.tiles[10][tx] = .ground; // a floor to stay grounded on
    var c = types.Character{ .x = 32, .y = 50 - types.HEIGHT, .on_ground = true, .hit_stun_timer = 1 };
    update(&c, w4.BUTTON_RIGHT | w4.BUTTON_1, 0); // still stunned this frame -> input ignored
    try testing.expectEqual(@as(f32, 0), c.vel_x); // no acceleration, and friction already zeroed it
    try testing.expect(c.vel_y != JUMP_VELOCITY);
    try testing.expectEqual(@as(u16, 0), c.hit_stun_timer);

    update(&c, w4.BUTTON_RIGHT | w4.BUTTON_1, 0); // stun has expired -> input works again
    try testing.expectEqual(JUMP_VELOCITY, c.vel_y);
}

test "takeDamage is a no-op while invulnerable" {
    var c = types.Character{ .hp = types.BASE_MAX_HP, .invuln_timer = 10 };
    takeDamage(&c, 1, 0);
    try testing.expectEqual(types.BASE_MAX_HP, c.hp);
}

test "pressing into a wall while airborne registers wall_side and slides slower" {
    room_types.active = .{};
    for (0..room_types.GRID_H) |ty| room_types.active.tiles[ty][10] = .wall; // a wall just to the right
    var c = types.Character{ .x = 42, .y = 40, .on_ground = false, .vel_y = 10 };
    update(&c, w4.BUTTON_RIGHT, 0); // first contact this frame -- registers wall_side
    try testing.expectEqual(@as(i8, 1), c.wall_side);

    update(&c, w4.BUTTON_RIGHT, 0); // now clinging -- gravity gets capped to the slide speed
    try testing.expectEqual(gravity.WALL_SLIDE_SPEED, c.vel_y);
}

test "jumping while clinging to a wall kicks off it and away" {
    room_types.active = .{};
    for (0..room_types.GRID_H) |ty| room_types.active.tiles[ty][10] = .wall;
    var c = types.Character{ .x = 42, .y = 40, .on_ground = false, .wall_side = 1 };
    update(&c, w4.BUTTON_1, 0);

    try testing.expectEqual(JUMP_VELOCITY, c.vel_y);
    try testing.expect(c.vel_x < 0); // wall was on the right -> kicked left
    try testing.expect(!c.facing_right); // now facing the direction it's kicking off toward
    try testing.expectEqual(@as(i8, 0), c.wall_side);
}

test "wall_side clears the instant the character lands" {
    room_types.active = .{};
    var c = types.Character{ .wall_side = 1, .on_ground = true, .vel_y = 0 };
    update(&c, w4.BUTTON_RIGHT, 0);
    try testing.expectEqual(@as(i8, 0), c.wall_side);
}

test "landing on the ground from the air starts the squash timer" {
    room_types.active = .{};
    room_types.active.tiles[10][6] = .ground; // a floor to land on
    var c = types.Character{ .x = 30, .y = 42, .on_ground = false, .vel_y = 10 };
    update(&c, 0, 0);
    try testing.expect(c.squash_timer > 0);
}

test "the squash timer counts down and does not retrigger while already grounded" {
    room_types.active = .{};
    var c = types.Character{ .on_ground = true, .squash_timer = 2 };
    update(&c, 0, 0);
    try testing.expectEqual(@as(u8, 1), c.squash_timer);
}

test "the jump button starts a swirl attack in the air, but still just jumps on the ground" {
    room_types.active = .{};
    var airborne = types.Character{ .x = 32, .y = 40, .on_ground = false };
    update(&airborne, w4.BUTTON_1, 0);
    try testing.expect(airborne.swing_timer > 0);
    try testing.expect(airborne.vel_y != JUMP_VELOCITY);

    room_types.active.tiles[10][6] = .ground; // a floor, so "grounded" actually stays grounded
    var grounded = types.Character{ .x = 32, .y = 40, .on_ground = true };
    update(&grounded, w4.BUTTON_1, 0);
    try testing.expectEqual(JUMP_VELOCITY, grounded.vel_y);
    try testing.expectEqual(@as(u8, 0), grounded.swing_timer);
}

test "clinging to a wall still wall-jumps instead of swirling" {
    room_types.active = .{};
    for (0..room_types.GRID_H) |ty| room_types.active.tiles[ty][10] = .wall;
    var c = types.Character{ .x = 42, .y = 40, .on_ground = false, .wall_side = 1 };
    update(&c, w4.BUTTON_1, 0);
    try testing.expectEqual(JUMP_VELOCITY, c.vel_y);
    try testing.expectEqual(@as(u8, 0), c.swing_timer);
}
