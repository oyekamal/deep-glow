extends Area2D
## Glowing pearl: bobbing bonus pickup that blinks before it fades away.

const LIFE := 6.0
var _t := 0.0
var _base := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"pearls")
	_base = position
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	position = _base + Vector2(0, sin(_t * 3.0) * 4.0)
	if _t > LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _t > LIFE - 1.5 and int(_t * 10.0) % 2 == 0:
		return
	var p := 1.0 + 0.15 * sin(_t * 6.0)
	for i in 4:
		draw_circle(Vector2.ZERO, (26.0 - i * 5.0) * p, Color(0.75, 0.8, 1.0, 0.05 * (i + 1)))
	draw_circle(Vector2.ZERO, 8.0, Color(0.88, 0.9, 1.0))
	draw_circle(Vector2.ZERO, 5.0, Color(1.7, 1.7, 2.0))
	draw_circle(Vector2(-2.5, -2.5), 2.0, Color.WHITE)
	# orbiting sparkle
	var s := Vector2.from_angle(_t * 4.0) * 14.0
	draw_circle(s, 1.8, Color(1.6, 1.6, 2.0, 0.9))
