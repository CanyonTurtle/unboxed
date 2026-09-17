// Orchestrates one frame: advances every entity's *.sim.zig, then reacts to
// its Event -- frozen except for the camera slide during a room transition.

const w4 = @import("../wasm4.zig");
const input = @import("../core/core.input.zig");
const room_types = @import("../room/room.types.zig");
const char_types = @import("../character/character.types.zig");
const char_sim = @import("../character/character.sim.zig");
const pot_types = @import("../pot/pot.types.zig");
const pot_sim = @import("../pot/pot.sim.zig");
const item_types = @import("../item/item.types.zig");
const item_sim = @import("../item/item.sim.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const enemy_sim = @import("../enemy/enemy.sim.zig");
const powerup_types = @import("../powerup/powerup.types.zig");
const powerup_sim = @import("../powerup/powerup.sim.zig");
const particle_types = @import("../particle/particle.types.zig");
const particle_sim = @import("../particle/particle.sim.zig");
const map_types = @import("../map/map.types.zig");
const map_sim = @import("../map/map.sim.zig");
const state = @import("game.types.zig");

const COIN_SCORE: u32 = 10;
const HEART_HEAL: i32 = 1;
const EXTRA_HP_GRANT: i32 = 2;

pub fn newRun() void {
    state.game = .{};
    map_sim.newRun();
    char_types.player = .{
        .x = 2 * room_types.TILE_SIZE,
        .y = (@as(f32, @floatFromInt(room_types.GRID_H)) - 4) * room_types.TILE_SIZE,
    };
}

// Drops a random item into the first free (collected) item slot -- silently
// does nothing if every slot is already occupied by an uncollected item.
fn revealItemAt(x: f32, y: f32) void {
    for (&item_types.items) |*item| {
        if (!item.collected) continue;
        const kind: item_types.ItemKind = if (state.game.rng.range(2) == 0) .coin else .heart;
        item.* = .{ .x = x, .y = y, .kind = kind, .collected = false };
        return;
    }
}

// A permanent upgrade -- applied once, here, since only game.sim is allowed
// to know both "a powerup was collected" and what player fields it changes.
fn grantPowerup(kind: powerup_types.PowerupKind) void {
    switch (kind) {
        .extra_hp => {
            char_types.player.max_hp += EXTRA_HP_GRANT;
            char_types.player.hp += EXTRA_HP_GRANT;
        },
    }
}

pub fn update(gamepad: u8) void {
    if (state.game.game_over) {
        if (input.justPressed(gamepad, state.game.prev_gamepad, w4.BUTTON_1)) newRun();
        state.game.prev_gamepad = gamepad;
        return;
    }

    if (map_types.transition.active) {
        map_sim.update(&char_types.player);
        state.game.prev_gamepad = gamepad;
        return;
    }

    char_sim.update(&char_types.player, gamepad, state.game.prev_gamepad);
    map_sim.update(&char_types.player);

    for (&pot_types.pots) |*pot| {
        if (pot_sim.update(pot, char_types.player.aabb()) == .broke) {
            revealItemAt(pot.x, pot.y);
            particle_sim.spawnBurst(pot.x, pot.y);
        }
    }

    for (&item_types.items) |*item| {
        switch (item_sim.update(item, char_types.player.aabb())) {
            .none => {},
            .collected => |kind| {
                particle_sim.spawnBurst(item.x, item.y);
                switch (kind) {
                    .coin => char_types.player.score += COIN_SCORE,
                    .heart => char_types.player.hp = @min(char_types.player.hp + HEART_HEAL, char_types.player.max_hp),
                }
            },
        }
    }

    for (&enemy_types.enemies) |*enemy| {
        switch (enemy_sim.update(enemy, char_types.player.aabb())) {
            .none => {},
            .hit_player => |amount| char_sim.takeDamage(&char_types.player, amount, enemy.x),
        }
        // The only way to defeat an enemy: the midair swirl attack, checked
        // separately since its hitbox is the character's, not the enemy's, to know about.
        if (enemy.alive) {
            if (char_types.player.swingHitbox()) |sword| {
                if (enemy.aabb().overlaps(sword)) {
                    enemy.alive = false;
                    particle_sim.spawnBurst(enemy.x, enemy.y);
                }
            }
        }
    }

    switch (powerup_sim.update(&powerup_types.active, char_types.player.aabb())) {
        .none => {},
        .collected => |kind| grantPowerup(kind),
    }

    particle_sim.update();

    if (char_types.player.hp <= 0) state.game.game_over = true;

    state.game.prev_gamepad = gamepad;
}

const testing = @import("std").testing;

test "newRun resets hp/score/upgrades and starts a fresh room" {
    newRun();
    try testing.expectEqual(char_types.BASE_MAX_HP, char_types.player.hp);
    try testing.expectEqual(char_types.BASE_MAX_HP, char_types.player.max_hp);
    try testing.expectEqual(@as(u32, 0), char_types.player.score);
    try testing.expectEqual(@as(u32, 0), map_types.room_index);
}

// Clears every pot/enemy/item/powerup, and the room's own generated
// terrain, so a test's hardcoded position can never collide with either.
fn clearField() void {
    room_types.active = .{};
    for (&pot_types.pots) |*p| p.* = .{ .broken = true };
    for (&enemy_types.enemies) |*e| e.* = .{ .alive = false };
    for (&item_types.items) |*it| it.* = .{};
    powerup_types.active = .{};
}

test "breaking a pot reveals an item that the player immediately picks up" {
    newRun();
    clearField();
    pot_types.pots[0] = .{ .x = 40, .y = 40, .broken = false };
    char_types.player = .{ .x = 40, .y = 40, .hp = char_types.BASE_MAX_HP - 2, .score = 0 };
    const hp_before = char_types.player.hp;

    update(0);

    try testing.expect(pot_types.pots[0].broken);
    // The revealed item spawns right where the player already stands, so
    // it's picked up the same frame -- either the score or hp changed.
    const got_coin = char_types.player.score == COIN_SCORE;
    const got_heart = char_types.player.hp == hp_before + HEART_HEAL;
    try testing.expect(got_coin or got_heart);
}

test "collecting a coin increases score" {
    newRun();
    clearField();
    item_types.items[0] = .{ .x = 40, .y = 40, .kind = .coin, .collected = false };
    char_types.player = .{ .x = 40, .y = 40, .score = 0 };

    update(0);

    try testing.expectEqual(COIN_SCORE, char_types.player.score);
}

test "collecting an extra_hp powerup raises both hp and max_hp" {
    newRun();
    clearField();
    powerup_types.active = .{ .x = 40, .y = 40, .kind = .extra_hp, .placed = true, .revealed = true };
    char_types.player = .{ .x = 40, .y = 40 };
    const max_before = char_types.player.max_hp;

    update(0);

    try testing.expectEqual(max_before + EXTRA_HP_GRANT, char_types.player.max_hp);
}

test "player hp reaching zero ends the run" {
    newRun();
    clearField();
    char_types.player.hp = 0;
    update(0);
    try testing.expect(state.game.game_over);
}

test "a midair sword swing defeats an enemy on contact" {
    newRun();
    clearField();
    enemy_types.enemies[0] = .{ .kind = .walker, .x = 50, .y = 40, .alive = true };
    char_types.player = .{ .x = 40, .y = 40, .facing_right = true, .swing_timer = 5, .surface = null };

    update(0);

    try testing.expect(!enemy_types.enemies[0].alive);
}

test "defeating an enemy spawns particles" {
    newRun();
    clearField();
    particle_sim.clear();
    enemy_types.enemies[0] = .{ .x = 40, .y = 40, .alive = true };
    char_types.player = .{ .x = 40, .y = 40, .swing_timer = 5, .surface = null };

    update(0);

    var live: u32 = 0;
    for (particle_types.particles) |p| {
        if (p.life > 0) live += 1;
    }
    try testing.expect(live > 0);
}
