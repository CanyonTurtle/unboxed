// A short-lived visual pop -- pure data; see particle.sim.zig for motion
// and particle.render.zig for the (deliberately tiny) look.

pub const MAX_COUNT: u32 = 24;

pub const Particle = struct {
    x: f32 = 0,
    y: f32 = 0,
    vel_x: f32 = 0,
    vel_y: f32 = 0,
    // Frames left to live; 0 means this slot is free for reuse.
    life: u8 = 0,
};

pub var particles: [MAX_COUNT]Particle = [_]Particle{.{}} ** MAX_COUNT;
