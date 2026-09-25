class_name Enemy
extends Area2D
## Abyss creature. Three kinds, all drawn in code. Darts telegraph with an edge warning first.

enum Kind { JELLY, URCHIN, DART }

const COLORS := {
	Kind.JELLY: Color(1.0, 0.33, 0.62),
	Kind.URCHIN: Color(1.0, 0.56, 0.22),
	Kind.DART: Color(1.0, 0.25, 0.3),
}
const SCALE := 1.35
const RADII := {Kind.JELLY: 17.0, Kind.URCHIN: 13.0, Kind.DART: 9.0}

var kind: int = Kind.JELLY
var velocity := Vector2.ZERO
var armed := false  # harmful? false while telegraphing / dying
var near := false  # entered the close-call ring
var grazed := false  # close-call already paid out
var target: Node2D  # who the eyes follow
var warn_time := 0.0
var _t := 0.0
var _spin := 0.0
var _dying := false
var _warn_pos := Vector2.ZERO

@onready var trail: Line2D = $Trail
@onready var shape: CollisionShape2D = $CollisionShape2D


func setup(k: int, pos: Vector2, vel: Vector2, watcher: Node2D, telegraph := 0.0) -> void:
	kind = k
	position = pos
	velocity = vel
	target = watcher
	warn_time = telegraph
	_t = randf() * 10.0
	_spin = randf_range(-3.0, 3.0)


func _ready() -> void:
	add_to_group(&"enemies")
	trail.top_level = true
	var g := Gradient.new()  # per-instance: trail fades from clear to the creature's colour
	g.set_color(0, Color(COLORS[kind], 0.0))
	g.set_color(1, Color(COLORS[kind] * 1.2, 0.7))
	trail.gradient = g
	var circle := CircleShape2D.new()  # own shape so radii never leak between instances
	circle.radius = RADII[kind]
	shape.shape = circle
	if kind == Kind.DART:
		trail.width = 12.0
	armed = warn_time <= 0.0
	scale = Vector2(SCALE, SCALE)
	if warn_time > 0.0:
		var vp := get_viewport_rect().size
		_warn_pos = position.clamp(Vector2(22, 22), vp - Vector2(22, 22))


func _physics_process(delta: float) -> void:
	_t += delta
	if warn_time > 0.0:
		warn_time -= delta
		if warn_time <= 0.0:
			armed = true
		queue_redraw()
		return
	var v := velocity
	if kind == Kind.JELLY:  # pulse-swim: speed surges on each contraction
		v *= 0.55 + 0.9 * maxf(0.0, sin(_t * 5.0))
		v += velocity.orthogonal().normalized() * sin(_t * 2.0) * 25.0
	position += v * delta
	rotation = 0.0
	if kind == Kind.URCHIN:
		_spin += delta
	if not _dying:
		trail.add_point(global_position)
		while trail.get_point_count() > (26 if kind == Kind.DART else 14):
			trail.remove_point(0)
	var vp := get_viewport_rect().size
	if not Rect2(Vector2(-120, -120), vp + Vector2(240, 240)).has_point(position):
		queue_free()
	queue_redraw()


## Popped by a hit or by clearing the board: shrink + fade, never harmful again.
func pop() -> void:
	if _dying:
		return
	_dying = true
	armed = false
	shape.set_deferred(&"disabled", true)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", scale * 1.6, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(trail, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)


func _eye(at: Vector2, r: float) -> void:
	var look := Vector2.ZERO
	if is_instance_valid(target) and target.visible:
		look = (target.global_position - global_position - at).limit_length(1.0) * r * 0.35
	draw_circle(at, r, Color(1, 0.96, 0.9))
	draw_circle(at + look, r * 0.55, Color(0.12, 0.02, 0.05))


func _draw() -> void:
	var c: Color = COLORS[kind]
	if warn_time > 0.0:
		_draw_warning(c)
		return
	var dir := velocity.normalized()
	match kind:
		Kind.JELLY:
			var p := 1.0 + 0.12 * sin(_t * 5.0)
			for i in 3:
				draw_circle(Vector2.ZERO, 30.0 - i * 6.0, Color(c, 0.05 * (i + 1)))
			for k in 5:  # tentacles hang opposite the swim direction
				var pts := PackedVector2Array()
				var base := Vector2((k - 2) * 6.0 * p, 6.0)
				for s in 6:
					pts.append(base + Vector2(sin(_t * 6.0 + s * 0.8 + k) * (1.5 + s), s * 4.5))
				draw_polyline(pts, Color(c, 0.75), 2.0, true)
			var dome := PackedVector2Array()
			for i in 17:
				var ang := PI + PI * i / 16.0
				dome.append(Vector2(cos(ang) * 17.0 * p, sin(ang) * 15.0 / p))
			for i in 7:  # scalloped rim
				var x := 17.0 * p - i * (34.0 * p / 6.0)
				dome.append(Vector2(x, 4.0 + (i % 2) * 3.0))
			draw_colored_polygon(dome, c)
			draw_circle(Vector2(-5, -8), 3.0, Color(1.8, 1.4, 1.6, 0.9))
			_eye(Vector2(-6, -3), 4.0)
			_eye(Vector2(6, -3), 4.0)
		Kind.URCHIN:
			for i in 3:
				draw_circle(Vector2.ZERO, 26.0 - i * 5.0, Color(c, 0.05 * (i + 1)))
			var spikes := PackedVector2Array()
			for i in 28:
				var ang := _spin * _spin_sign() + TAU * i / 28.0
				var r := 21.0 if i % 2 == 0 else 12.0
				spikes.append(Vector2.from_angle(ang) * r)
			draw_colored_polygon(spikes, c.darkened(0.15))
			draw_circle(Vector2.ZERO, 12.0, c)
			draw_circle(Vector2(-4, -5), 2.5, Color(1.8, 1.5, 1.2, 0.9))
			_eye(Vector2.ZERO, 5.5)
		Kind.DART:
			var side := dir.orthogonal()
			for i in 3:
				draw_circle(Vector2.ZERO, 22.0 - i * 5.0, Color(c, 0.06 * (i + 1)))
			var body := PackedVector2Array([
				dir * 18.0, side * 7.0, -dir * 14.0 + side * 3.0, -dir * 20.0 + side * 8.0,
				-dir * 17.0, -dir * 20.0 - side * 8.0, -dir * 14.0 - side * 3.0, -side * 7.0])
			draw_colored_polygon(body, c)
			draw_line(dir * 14.0, -dir * 10.0, Color(1.8, 1.2, 1.2, 0.8), 2.0, true)
			_eye(dir * 6.0 + side * 2.5, 3.2)


func _spin_sign() -> float:
	return 1.0 if velocity.x >= 0.0 else -1.0


func _draw_warning(c: Color) -> void:
	# drawn in world space at the clamped edge spot; node itself is still off-screen
	var local := _warn_pos - position
	var dir := velocity.normalized()
	var on := int(_t * 12.0) % 2 == 0
	var s := 1.0 + 0.25 * sin(_t * 20.0)
	var tri := PackedVector2Array([
		local + dir * 12.0 * s, local - dir * 6.0 + dir.orthogonal() * 10.0 * s,
		local - dir * 6.0 - dir.orthogonal() * 10.0 * s])
	draw_circle(local, 20.0 * s, Color(c, 0.12))
	draw_arc(local, 18.0 * s, 0.0, TAU, 24, Color(c, 0.9 if on else 0.4), 2.5, true)
	draw_colored_polygon(tri, Color(c, 1.0 if on else 0.5))
