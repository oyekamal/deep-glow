class_name Player
extends Area2D
## Lumi: a little bioluminescent squid. Swims with eased acceleration, faces its motion,
## trails light, blinks while invulnerable.

signal hit(enemy: Enemy)
signal pearl_collected(pearl: Area2D)

const BODY := Color(0.55, 1.0, 0.88)
const CORE := Color(1.6, 2.0, 1.8)  # HDR: blooms with 2D glow
const EYE := Color(0.03, 0.09, 0.12)

@export var max_speed := 330.0
@export var accel := 9.0

var velocity := Vector2.ZERO
var facing := -PI / 2  # points up
var alive := false
var invulnerable := 0.0
var flash := 0.0
var _t := 0.0

@onready var trail: Line2D = $Trail
@onready var bubbles: CPUParticles2D = $Bubbles
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	trail.top_level = true
	hide()
	set_physics_process(false)


func start(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	facing = -PI / 2
	alive = true
	invulnerable = 1.2
	trail.clear_points()
	show()
	set_physics_process(true)
	shape.set_deferred(&"disabled", false)
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2(1.4, 1.4), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func stop() -> void:
	alive = false
	hide()
	set_physics_process(false)
	shape.set_deferred(&"disabled", true)
	trail.clear_points()
	bubbles.emitting = false


func take_hit() -> void:
	invulnerable = 1.6
	flash = 1.0


func _physics_process(delta: float) -> void:
	_t += delta
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = velocity.lerp(input * max_speed, 1.0 - exp(-accel * delta))
	position += velocity * delta
	var vp := get_viewport_rect().size
	position = position.clamp(Vector2(24, 24), vp - Vector2(24, 24))

	if velocity.length() > 25.0:
		facing = lerp_angle(facing, velocity.angle(), 1.0 - exp(-14.0 * delta))
	bubbles.emitting = velocity.length() > 120.0
	bubbles.direction = -Vector2.from_angle(facing)

	invulnerable = maxf(0.0, invulnerable - delta)
	flash = maxf(0.0, flash - delta * 4.0)

	if invulnerable <= 0.0:  # scan overlaps too: an enemy still inside us when i-frames end must count
		for area in get_overlapping_areas():
			if area.is_in_group(&"enemies") and area.get(&"armed"):
				hit.emit(area as Enemy)
				break

	trail.add_point(global_position - Vector2.from_angle(facing) * 10.0)
	while trail.get_point_count() > 22:
		trail.remove_point(0)
	queue_redraw()


func _draw() -> void:
	var blink := invulnerable > 0.0 and int(invulnerable * 14.0) % 2 == 0
	var a := 0.35 if blink else 1.0
	var speed_k := clampf(velocity.length() / max_speed, 0.0, 1.0)
	var fwd := Vector2.from_angle(facing)
	var side := fwd.orthogonal()
	var body := BODY.lerp(Color.WHITE, flash)
	# soft halo
	for i in 4:
		draw_circle(Vector2.ZERO, 34.0 - i * 6.0, Color(0.4, 1.0, 0.85, 0.07 * a * (i + 1)))
	# tentacles trail behind, wiggling
	for k in 3:
		var off := (k - 1) * 5.0
		var pts := PackedVector2Array()
		for s in 6:
			var d := 6.0 + s * (3.2 + speed_k * 1.6)
			var wig := sin(_t * 14.0 + s * 0.9 + k * 2.0) * (1.0 + s * 0.8) * (1.0 - speed_k * 0.4)
			pts.append(-fwd * d + side * (off * (1.0 - s * 0.08) + wig))
		draw_polyline(pts, Color(body, 0.8 * a), 2.5 - k * 0.2, true)
	# mantle: teardrop pointing along facing, stretched when fast
	var stretch := 1.0 + speed_k * 0.25
	var poly := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		var r := 11.0 + 5.0 * maxf(0.0, cos(ang)) * stretch
		var w := 1.0 - speed_k * 0.12
		poly.append(fwd * cos(ang) * r + side * sin(ang) * 11.0 * w)
	draw_colored_polygon(poly, Color(body, a))
	draw_circle(fwd * 2.0, 5.5, Color(CORE, a))
	# eyes look where we are going
	for sgn in [-1.0, 1.0]:
		var e: Vector2 = fwd * 5.0 + side * 5.0 * sgn
		draw_circle(e, 3.4, Color(Color.WHITE, a))
		draw_circle(e + fwd * 1.2, 2.0, Color(EYE, a))


func _on_area_entered(area: Area2D) -> void:
	if not alive:
		return
	if area.is_in_group(&"pearls"):
		pearl_collected.emit(area)
	elif area.is_in_group(&"enemies") and invulnerable <= 0.0 and area.get(&"armed"):
		hit.emit(area as Enemy)
