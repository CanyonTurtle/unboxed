// Shared gamepad edge-detection: compares this frame's gamepad byte against
// last frame's, so no module re-derives "just pressed" logic on its own.

pub fn justPressed(gamepad: u8, prev_gamepad: u8, button: u8) bool {
    return (gamepad & button != 0) and (prev_gamepad & button == 0);
}

pub fn held(gamepad: u8, button: u8) bool {
    return gamepad & button != 0;
}

pub fn justReleased(gamepad: u8, prev_gamepad: u8, button: u8) bool {
    return (gamepad & button == 0) and (prev_gamepad & button != 0);
}

test "justPressed is true only on the frame a button transitions from up to down" {
    const testing = @import("std").testing;
    const BTN: u8 = 1;
    try testing.expect(justPressed(BTN, 0, BTN));
    try testing.expect(!justPressed(BTN, BTN, BTN));
    try testing.expect(!justPressed(0, 0, BTN));
    try testing.expect(!justPressed(0, BTN, BTN));
}

test "held reflects the current frame's gamepad state regardless of last frame" {
    const testing = @import("std").testing;
    const BTN: u8 = 2;
    try testing.expect(held(BTN, BTN));
    try testing.expect(!held(0, BTN));
}

test "justReleased is true only on the frame a button transitions from down to up" {
    const testing = @import("std").testing;
    const BTN: u8 = 4;
    try testing.expect(justReleased(0, BTN, BTN));
    try testing.expect(!justReleased(BTN, BTN, BTN));
    try testing.expect(!justReleased(0, 0, BTN));
    try testing.expect(!justReleased(BTN, 0, BTN));
}
