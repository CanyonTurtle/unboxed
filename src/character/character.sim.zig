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
const JUMP_VELOCITY: f32 = -3.6;
const INVULN_FRAMES: u16 = 45;
const DAMAGE_KNOCKBACK: f32 = 2.0;

pub fn update(self: *types.Character, gamepad: u8, prev_gamepad: u8) void {
    if (input.held(gamepad, w4.BUTTON_LEFT)) {
        self.vel_x -= MOVE_ACCEL;
        self.facing_right = false;
    } else if (input.held(gamepad, w4.BUTTON_RIGHT)) {
        self.vel_x += MOVE_ACCEL;
        self.facing_right = true;
    } else {
        self.vel_x *= FRICTION;
    }
    self.vel_x = std.math.clamp(self.vel_x, -MOVE_MAX_SPEED, MOVE_MAX_SPEED);

    if (self.on_ground) self.air_jumps_used = 0;
    gravity.apply(&self.vel_y, self.on_ground);

    // Applied after gravity so a jump always snaps to exactly JUMP_VELOCITY
    // this frame, whether it's the on-ground jump or a double-jump.
    if (input.justPressed(gamepad, prev_gamepad, w4.BUTTON_1)) {
        if (self.on_ground) {
            self.vel_y = JUMP_VELOCITY;
        } else if (self.has_double_jump and self.air_jumps_used < 1) {
            self.vel_y = JUMP_VELOCITY;
            self.air_jumps_used += 1;
        }
    }

    const tiles = collision.TileQuery{ .tile_size = room_types.TILE_SIZE, .isSolid = &room_types.isSolid };
    const result = collision.moveAndCollide(&self.x, &self.y, types.WIDTH, types.HEIGHT, &self.vel_x, &self.vel_y, tiles);
    self.on_ground = result.on_ground;

    if (self.invuln_timer > 0) self.invuln_timer -= 1;
}

// Applies contact damage, knocking the character back away from `from_x`.
// A no-op while still invulnerable from a previous hit.
pub fn takeDamage(self: *types.Character, amount: i32, from_x: f32) void {
    if (self.invuln_timer > 0) return;
    self.hp = @max(0, self.hp - amount);
    self.vel_x = if (self.x < from_x) -DAMAGE_KNOCKBACK else DAMAGE_KNOCKBACK;
    self.vel_y = -1.5;
    self.invuln_timer = INVULN_FRAMES;
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
    try testing.expect(c.vel_y != -3.6);

    c = types.Character{ .x = 32, .y = 80, .on_ground = true };
    update(&c, w4.BUTTON_1, 0);
    try testing.expectEqual(@as(f32, -3.6), c.vel_y);
}

test "takeDamage reduces hp, applies knockback, and starts invulnerability" {
    var c = types.Character{ .x = 20, .hp = types.BASE_MAX_HP };
    takeDamage(&c, 1, 30); // hazard to the right -> knocked left
    try testing.expectEqual(types.BASE_MAX_HP - 1, c.hp);
    try testing.expect(c.vel_x < 0);
    try testing.expect(c.invuln_timer > 0);
}

test "takeDamage is a no-op while invulnerable" {
    var c = types.Character{ .hp = types.BASE_MAX_HP, .invuln_timer = 10 };
    takeDamage(&c, 1, 0);
    try testing.expectEqual(types.BASE_MAX_HP, c.hp);
}

test "has_double_jump grants exactly one extra jump while airborne" {
    room_types.active = .{};
    var c = types.Character{ .x = 32, .y = 40, .on_ground = false, .has_double_jump = true };
    update(&c, w4.BUTTON_1, 0); // first air jump
    try testing.expectEqual(@as(f32, -3.6), c.vel_y);

    c.vel_y = 1; // pretend gravity has been pulling it back down since
    update(&c, w4.BUTTON_1, 0); // second press -- no jumps left
    try testing.expect(c.vel_y != -3.6); // gravity's own nudge, not a fresh jump
}

test "without has_double_jump, an air jump press does nothing" {
    room_types.active = .{};
    var c = types.Character{ .x = 32, .y = 40, .on_ground = false, .has_double_jump = false };
    update(&c, w4.BUTTON_1, 0);
    try testing.expect(c.vel_y != -3.6);
}

test "landing resets air_jumps_used so the next fall grants a fresh double jump" {
    room_types.active = .{};
    var c = types.Character{ .has_double_jump = true, .air_jumps_used = 1, .on_ground = true };
    update(&c, 0, 0);
    try testing.expectEqual(@as(u8, 0), c.air_jumps_used);
}
