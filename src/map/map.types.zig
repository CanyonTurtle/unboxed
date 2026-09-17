// Forward-only room progression: you can never go back, so only the
// current room and the one you're transitioning into ever need to exist.

const room_types = @import("../room/room.types.zig");
const pot_types = @import("../pot/pot.types.zig");
const item_types = @import("../item/item.types.zig");
const enemy_types = @import("../enemy/enemy.types.zig");
const powerup_types = @import("../powerup/powerup.types.zig");
const key_types = @import("../key/key.types.zig");

pub const RoomSave = struct {
    room: room_types.Room = .{},
    pots: [pot_types.MAX_COUNT]pot_types.Pot = [_]pot_types.Pot{.{}} ** pot_types.MAX_COUNT,
    items: [item_types.MAX_COUNT]item_types.Item = [_]item_types.Item{.{}} ** item_types.MAX_COUNT,
    enemies: [enemy_types.MAX_COUNT]enemy_types.Enemy = [_]enemy_types.Enemy{.{}} ** enemy_types.MAX_COUNT,
    powerup: powerup_types.Powerup = .{},
    key: key_types.Key = .{},
};

pub var current: RoomSave = .{};
pub var next: RoomSave = .{};

// Which side of `current` the player walked in through -- null only for the
// very first room, which has no entry side and so no side to exclude.
pub var entered_from: ?room_types.Side = null;

// Increases every transition; the only source of "how deep is this run" now
// that there's no room-graph coordinate to measure distance from.
pub var room_index: u32 = 0;

pub const TRANSITION_FRAMES: u16 = 18;

pub const Transition = struct {
    active: bool = false,
    dir: room_types.Side = .left,
    frame: u16 = 0,
    start_x: f32 = 0,
    start_y: f32 = 0,
    end_x: f32 = 0,
    end_y: f32 = 0,
};
pub var transition: Transition = .{};

// A door can only ever open on these 3 sides -- reaching "up" is real
// platforming (see room.types.exitSpan), never a way to leave the room.
pub const DOOR_SIDES = [3]room_types.Side{ .left, .right, .down };

pub fn opposite(side: room_types.Side) room_types.Side {
    return switch (side) {
        .up => .down,
        .down => .up,
        .left => .right,
        .right => .left,
    };
}

// A room's valid doors: every DOOR_SIDES entry except whichever one you
// entered through -- never a way straight back to the room you just left.
pub fn isValidDoor(side: room_types.Side, entered: ?room_types.Side) bool {
    if (entered != null and side == entered.?) return false;
    for (DOOR_SIDES) |s| {
        if (s == side) return true;
    }
    return false;
}

const testing = @import("std").testing;

test "opposite is its own inverse for every side" {
    inline for (.{ room_types.Side.up, .down, .left, .right }) |side| {
        try testing.expectEqual(side, opposite(opposite(side)));
    }
}

test "isValidDoor excludes the entry side but allows the other two" {
    try testing.expect(!isValidDoor(.left, .left));
    try testing.expect(isValidDoor(.right, .left));
    try testing.expect(isValidDoor(.down, .left));
}

test "isValidDoor never allows up, entry side or not" {
    try testing.expect(!isValidDoor(.up, null));
    try testing.expect(!isValidDoor(.up, .left));
}

test "with no entry side (the start room), all 3 door sides are valid" {
    try testing.expect(isValidDoor(.left, null));
    try testing.expect(isValidDoor(.right, null));
    try testing.expect(isValidDoor(.down, null));
}
