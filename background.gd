extends Node2D
## Deep-sea backdrop: vertical gradient, swaying light shafts, drifting marine snow with parallax.

const TOP := Color(0.03, 0.2, 0.27)
const BOTTOM := Color(0.01, 0.03, 0.07)

@export var parallax_source: Node2D

var _t := 0.0
var _snow: Array[Vector3] = []  # x, y, depth(0.3..1)


func _ready() -> void:
	for i in 90:
		_snow.append(Vector3(randf() * 480.0, randf() * 720.0, randf_range(0.3, 1.0)))


func _process(delta: float) -> void:
	_t += delta
	for i in _snow.size():
		var s := _snow[i]
		s.y -= (6.0 + 14.0 * s.z) * delta  # snow drifts up slowly, like rising particles
		s.x += sin(_t * 0.7 + i) * 4.0 * delta
		if s.y < -4.0:
			s.y = 724.0
			s.x = randf() * 480.0
		_snow[i] = s
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	# light shafts from the surface
	for i in 4:
		var x := 60.0 + i * 120.0 + sin(_t * 0.4 + i * 1.7) * 30.0
		var w := 40.0 + 20.0 * sin(_t * 0.3 + i)
		var a := 0.05 + 0.025 * sin(_t * 0.6 + i * 2.3)
		draw_polygon(
			PackedVector2Array([Vector2(x - w * 0.3, 0), Vector2(x + w * 0.3, 0),
				Vector2(x + w * 1.6 - 80.0, vp.y * 0.85), Vector2(x - w * 1.6 - 80.0, vp.y * 0.85)]),
			PackedColorArray([Color(0.5, 1, 0.95, a), Color(0.5, 1, 0.95, a),
				Color(0.5, 1, 0.95, 0), Color(0.5, 1, 0.95, 0)]))
	var shift := Vector2.ZERO
	if is_instance_valid(parallax_source) and parallax_source.visible:
		shift = (parallax_source.position - vp / 2) * -0.04
	for s in _snow:
		var p := Vector2(s.x, s.y) + shift * s.z
		draw_circle(p, 0.6 + s.z * 1.3, Color(0.7, 0.95, 1.0, 0.12 + s.z * 0.3))
	# seabed silhouette
	var bed := PackedVector2Array([Vector2(0, vp.y)])
	for i in 13:
		var x := i * vp.x / 12.0
		bed.append(Vector2(x, vp.y - 22.0 - 14.0 * sin(i * 1.9) - 8.0 * sin(i * 0.7 + 1.0)))
	bed.append(vp)
	draw_colored_polygon(bed, Color(0.0, 0.02, 0.04, 0.9))
