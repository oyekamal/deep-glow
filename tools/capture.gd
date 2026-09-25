extends SceneTree
# Neutral gameplay capture driver for gauntlet A/B. Usage (needs a display for Movie Maker):
#   DISPLAY=:1 godot --path <proj> -s res://../_tools/capture.gd --write-movie out/f.png --fixed-fps 30 --quit-after 450
# Frame 20: press Enter + click bottom-centre (Start). Then weaves left/right/up/down.

var f := 0

func _initialize() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e)

func _click(pos: Vector2) -> void:
	for down in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT; m.pressed = down; m.position = pos; m.global_position = pos
		Input.parse_input_event(m)

func _process(_delta: float) -> bool:
	f += 1
	var size := root.get_visible_rect().size
	if f == 20:
		_key(KEY_ENTER, true); _key(KEY_SPACE, true)
		_click(Vector2(size.x / 2, size.y * 0.8))
	if f == 22:
		_key(KEY_ENTER, false); _key(KEY_SPACE, false)
	if f > 40:
		var phase := (f / 45) % 4  # ponytail: fixed weave, deterministic enough for A/B
		var keys := [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]
		for i in 4:
			_key(keys[i], i == phase)
	return false
