// Top-level run state -- everything not owned by one entity kind (see
// character.types.player, pot.types.pots, etc. for that same `pub var` pattern).

const rng_mod = @import("../core/core.rng.zig");

pub const GameState = struct {
    prev_gamepad: u8 = 0,
    rng: rng_mod.Rng = .{ .state = 0xc0ffee },
    game_over: bool = false,
};

pub var game: GameState = .{};
