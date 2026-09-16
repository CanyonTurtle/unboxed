// A tiny, deterministic fan-out burst (no RNG needed) plus simple gravity,
// aging, and expiry -- shared by every "something broke/died/got collected" moment.

const types = @import("particle.types.zig");

const LIFE_FRAMES: u8 = 20;
const PARTICLE_GRAVITY: f32 = 0.15;

const BURST_DIRS = [_][2]f32{
    .{ 1, -1 },  .{ -1, -1 }, .{ 1, 1 }, .{ -1, 1 },
    .{ 1.4, 0 }, .{ -1.4, 0 }, .{ 0, -1.6 }, .{ 0, 1.2 },
};

// Fills up to BURST_DIRS.len free slots -- silently spawns fewer if the
// pool is nearly full, never overwrites a still-live particle.
pub fn spawnBurst(x: f32, y: f32) void {
    var dir_i: usize = 0;
    for (&types.particles) |*p| {
        if (dir_i >= BURST_DIRS.len) break;
        if (p.life > 0) continue;
        p.* = .{ .x = x, .y = y, .vel_x = BURST_DIRS[dir_i][0], .vel_y = BURST_DIRS[dir_i][1], .life = LIFE_FRAMES };
        dir_i += 1;
    }
}

pub fn update() void {
    for (&types.particles) |*p| {
        if (p.life == 0) continue;
        p.vel_y += PARTICLE_GRAVITY;
        p.x += p.vel_x;
        p.y += p.vel_y;
        p.life -= 1;
    }
}

// Called on a room transition -- particles are a per-room visual flourish,
// not state worth carrying into the next one.
pub fn clear() void {
    types.particles = [_]types.Particle{.{}} ** types.MAX_COUNT;
}

const testing = @import("std").testing;

test "spawnBurst fills free slots and update ages them out after LIFE_FRAMES" {
    clear();
    spawnBurst(10, 10);

    var live: u32 = 0;
    for (types.particles) |p| {
        if (p.life > 0) live += 1;
    }
    try testing.expectEqual(@as(u32, BURST_DIRS.len), live);

    var i: u32 = 0;
    while (i < LIFE_FRAMES) : (i += 1) update();

    for (types.particles) |p| try testing.expectEqual(@as(u8, 0), p.life);
}

test "spawnBurst never overwrites a still-live particle" {
    clear();
    types.particles[0] = .{ .x = 1, .y = 1, .life = 5 };
    spawnBurst(50, 50);
    try testing.expectEqual(@as(f32, 1), types.particles[0].x);
}

test "clear removes every particle regardless of remaining life" {
    clear();
    spawnBurst(0, 0);
    clear();
    for (types.particles) |p| try testing.expectEqual(@as(u8, 0), p.life);
}
