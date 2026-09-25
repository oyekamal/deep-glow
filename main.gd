extends Node2D
## Deep Glow: game flow (title -> ready -> play -> game over), spawning, scoring and juice.

enum State { TITLE, READY, PLAY, DEAD }

const ENEMY_SCENE := preload("res://enemy.tscn")
const PEARL_SCENE := preload("res://pearl.tscn")
const SFX := {
	"start": preload("res://audio/start.wav"),
	"tick": preload("res://audio/tick.wav"),
	"go": preload("res://audio/go.wav"),
	"pickup": preload("res://audio/pickup.wav"),
	"hit": preload("res://audio/hit.wav"),
	"death": preload("res://audio/death.wav"),
}
const FONT := preload("res://fonts/Quicksand-Bold.ttf")
const MINT := Color(0.55, 1.0, 0.88)
const PINK := Color(1.0, 0.36, 0.6)
const PEARL := Color(0.85, 0.88, 1.0)

var state := State.TITLE
var score := 0.0
var best := 0
var lives := 3
var play_time := 0.0
var trauma := 0.0
var _spawn_cd := 0.0
var _pearl_cd := 3.0
var _shown_score := -1

@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var pearls: Node2D = $Pearls
@onready var fx: Node2D = $FX
@onready var camera: Camera2D = $Camera2D
@onready var hud: Hud = $HUD
@onready var music: AudioStreamPlayer = $Music


func _ready() -> void:
	$Background.parallax_source = player
	player.hit.connect(_on_player_hit)
	player.pearl_collected.connect(_on_pearl)
	hud.start_pressed.connect(start_game)
	music.finished.connect(music.play)
	music.play()
	hud.show_title(best)
	_seed_attract()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.TITLE and event.is_action_pressed(&"start_game"):
		get_viewport().set_input_as_handled()
		start_game()


func start_game() -> void:
	if state != State.TITLE:
		return
	state = State.READY
	for e: Enemy in enemies.get_children():
		e.pop()
	for p in pearls.get_children():
		p.queue_free()
	score = 0.0
	play_time = 0.0
	lives = 3
	_spawn_cd = 0.0
	_pearl_cd = 2.5
	hud.hide_title()
	hud.set_lives(lives)
	hud.update_score(0)
	player.start(Vector2(240, 520))
	_sfx("start")
	burst(Vector2(240, 520), MINT, 28, 160.0)
	hud.show_message("READY?", 0.45)
	await get_tree().create_timer(0.75).timeout
	if state != State.READY:
		return
	hud.show_message("SWIM!", 0.3, Color(1.0, 0.95, 0.6))
	_sfx("go")
	state = State.PLAY


func _physics_process(delta: float) -> void:
	_update_shake(delta)
	match state:
		State.TITLE:
			_spawn_cd -= delta
			if _spawn_cd <= 0.0:  # attract mode: a lazy parade of jellies behind the title
				_spawn_cd = 1.1
				_spawn(enemy_kind_for(0.0), 0.6, false)
		State.PLAY:
			play_time += delta
			score += delta * 10.0
			var k := clampf(play_time / 60.0, 0.0, 1.0)
			_spawn_cd -= delta
			if _spawn_cd <= 0.0:
				_spawn_cd = lerpf(0.75, 0.26, k)
				_spawn(enemy_kind_for(play_time), 1.0 + play_time / 90.0, true)
			_pearl_cd -= delta
			if _pearl_cd <= 0.0:
				_pearl_cd = randf_range(2.5, 4.0)
				var pearl: Node2D = PEARL_SCENE.instantiate()
				pearl.position = Vector2(randf_range(50, 430), randf_range(90, 620))
				pearls.add_child(pearl)
			_check_grazes()
	var s := int(score)
	if s != _shown_score and state != State.TITLE:
		_shown_score = s
		hud.update_score(s)


## Title backdrop starts already populated instead of empty water.
func _seed_attract() -> void:
	for i in 5:
		var e: Enemy = ENEMY_SCENE.instantiate()
		var pos := Vector2(randf_range(40, 440), [randf_range(70, 130), randf_range(380, 440), randf_range(640, 690)].pick_random())
		var vel := Vector2.from_angle(randf() * TAU) * randf_range(50.0, 80.0)
		e.setup([0, 0, 1].pick_random(), pos, vel, player)
		enemies.add_child(e)
		e.modulate.a = 0.55


func enemy_kind_for(t: float) -> int:
	if state == State.TITLE:
		return [0, 0, 1].pick_random()
	var r := randf()
	if t > 6.0 and r < clampf(0.15 + t / 120.0, 0.0, 0.4):
		return 2  # DART
	return 1 if randf() < 0.45 else 0


func _spawn(kind: int, speed_mul: float, aimed: bool) -> void:
	var vp := get_viewport_rect().size
	var edge := randi() % 4
	var pos: Vector2
	match edge:
		0: pos = Vector2(randf() * vp.x, -40)
		1: pos = Vector2(vp.x + 40, randf() * vp.y)
		2: pos = Vector2(randf() * vp.x, vp.y + 40)
		_: pos = Vector2(-40, randf() * vp.y)
	# aim at a random point in the middle band (or near the player) so they cross the play area
	var goal := Vector2(randf_range(80, vp.x - 80), randf_range(120, vp.y - 120))
	if aimed and randf() < 0.35 and player.visible:
		goal = player.position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var base_speed: float = [120.0, 185.0, 360.0][kind]
	var vel := (goal - pos).normalized() * base_speed * randf_range(0.85, 1.15) * speed_mul
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(kind, pos, vel, player, 0.55 if kind == 2 else 0.0)
	enemies.add_child(e)
	if not aimed:
		e.modulate.a = 0.55


func _check_grazes() -> void:
	if player.invulnerable > 0.0:
		return
	# pay the close call only once the creature has passed without touching us
	for e: Enemy in enemies.get_children():
		if not e.armed or e.grazed:
			continue
		var inside: bool = e.position.distance_to(player.position) < Enemy.RADII[e.kind] * Enemy.SCALE + 34.0
		if inside:
			e.near = true
		elif e.near:
			e.grazed = true
			score += 20
			popup(player.position + Vector2(0, -30), "CLOSE +20", Color(1.0, 0.95, 0.6), 22)
			hud.update_score(int(score), true)


func _on_pearl(pearl: Area2D) -> void:
	score += 50
	_sfx("pickup", randf_range(0.95, 1.1))
	burst(pearl.global_position, PEARL, 18, 140.0)
	popup(pearl.global_position + Vector2(0, -20), "+50", PEARL, 30)
	hud.update_score(int(score), true)
	pearl.queue_free()


func _on_player_hit(enemy: Enemy) -> void:
	if state != State.PLAY:
		return
	lives -= 1
	hud.set_lives(lives)
	player.take_hit()
	enemy.pop()
	burst(player.position, Color(1.0, 0.4, 0.5), 30, 260.0)
	for e: Enemy in enemies.get_children():  # clear a breathing ring so one mistake isn't three
		if e.position.distance_to(player.position) < 110.0:
			burst(e.position, Enemy.COLORS[e.kind], 10, 120.0)
			e.pop()
	if lives <= 0:
		_die()
		return
	_sfx("hit")
	add_trauma(0.55)
	hud.flash_screen(Color(1, 0.3, 0.45), 0.22, 0.2)
	_hit_stop(0.07)


func _die() -> void:
	state = State.DEAD
	_sfx("death")
	add_trauma(1.0)
	hud.flash_screen(Color.WHITE, 0.5, 0.35)
	burst(player.position, MINT, 60, 360.0)
	burst(player.position, Color(1.0, 0.4, 0.5), 30, 220.0)
	player.stop()
	var final := int(score)
	var new_best := final > best
	best = maxi(best, final)
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.6, true, false, true).timeout
	Engine.time_scale = 1.0
	hud.show_game_over(final, best, new_best)
	await get_tree().create_timer(2.4).timeout
	state = State.TITLE
	_spawn_cd = 0.5
	hud.show_title(best)


func _hit_stop(real_seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if state == State.PLAY:
		Engine.time_scale = 1.0


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _update_shake(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.6)
	var amt := trauma * trauma
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * amt
	camera.rotation = randf_range(-1, 1) * 0.04 * amt


func burst(at: Vector2, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.7
	p.spread = 180.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(color * 1.6, 1.0))
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	p.finished.connect(p.queue_free)
	fx.add_child(p)
	p.emitting = true


func popup(at: Vector2, text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.01, 0.05, 0.08))
	l.add_theme_constant_override(&"outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(200, 40)
	l.position = Vector2(clampf(at.x, 90.0, 390.0), at.y) - Vector2(100, 20)
	l.pivot_offset = Vector2(100, 20)
	l.scale = Vector2(0.4, 0.4)
	fx.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _sfx(key: String, pitch := 1.0) -> void:
	var a := AudioStreamPlayer.new()
	a.stream = SFX[key]
	a.pitch_scale = pitch
	a.volume_db = -4.0
	a.finished.connect(a.queue_free)
	add_child(a)
	a.play()
