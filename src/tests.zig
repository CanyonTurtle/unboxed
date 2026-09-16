// Root file for `zig build test`. Skips main.zig and every *.render.zig --
// see README.md's Testing section for why.
test {
    _ = @import("core/core.sprite.zig");
    _ = @import("core/core.gravity.zig");
    _ = @import("core/core.collision.zig");
    _ = @import("core/core.input.zig");
    _ = @import("core/core.rng.zig");

    _ = @import("room/room.types.zig");
    _ = @import("room/room.sim.zig");

    _ = @import("character/character.sim.zig");
    _ = @import("pot/pot.sim.zig");
    _ = @import("item/item.sim.zig");
    _ = @import("enemy/enemy.sim.zig");
    _ = @import("powerup/powerup.sim.zig");

    _ = @import("map/map.types.zig");
    _ = @import("map/map.sim.zig");

    _ = @import("game/game.sim.zig");
}
