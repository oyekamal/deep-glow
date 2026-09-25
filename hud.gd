class_name Hud
extends CanvasLayer
## Title screen, in-game HUD (score / lives / best), centre messages, screen flash, vignette.

signal start_pressed

const MINT := Color(0.55, 1.0, 0.88)
const PINK := Color(1.0, 0.36, 0.6)

var lives := 3
var _title_tween: Tween
var _title_y := 0.0

@onready var ui: Control = $UI
@onready var vignette: TextureRect = $UI/Vignette
@onready var flash_rect: ColorRect = $UI/Flash
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var lives_bar: Control = $UI/Lives
@onready var title: Control = $UI/Title
@onready var title_label: Label = $UI/Title/TitleLabel
@onready var start_button: Button = $UI/Title/StartButton
@onready var message: Label = $UI/MessageLabel
@onready var sub_message: Label = $UI/SubMessage


func _ready() -> void:
	_title_y = title_label.position.y
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	lives_bar.draw.connect(_draw_lives)
	var tex := GradientTexture2D.new()  # any texture so the rect draws; the shader does the work
	tex.width = 4
	tex.height = 4
	vignette.texture = tex
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://vignette.gdshader")
	vignette.material = mat
	message.hide()
	sub_message.hide()


func _process(_delta: float) -> void:
	lives_bar.queue_redraw()


func show_title(best: int) -> void:
	title.show()
	score_label.hide()
	lives_bar.hide()
	best_label.text = "BEST  %d" % best if best > 0 else ""
	best_label.show()
	title.modulate.a = 0.0
	create_tween().tween_property(title, "modulate:a", 1.0, 0.5)
	if _title_tween:
		_title_tween.kill()
	title_label.position.y = _title_y
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "position:y", _title_y - 8.0, 1.2).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(title_label, "position:y", _title_y, 1.2).set_trans(Tween.TRANS_SINE)
	start_button.grab_focus()


func hide_title() -> void:
	if _title_tween:
		_title_tween.kill()
	start_button.release_focus()
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 0.0, 0.25)
	tw.tween_callback(title.hide)
	score_label.show()
	lives_bar.show()


func show_message(text: String, duration := 0.8, color := MINT) -> void:
	message.text = text
	message.modulate = color
	message.show()
	message.pivot_offset = message.size / 2
	message.scale = Vector2(1.8, 1.8)
	message.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(message, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(message, "modulate:a", 1.0, 0.15)
	tw.chain().tween_interval(duration)
	tw.chain().tween_property(message, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(message.hide)


func show_game_over(score: int, best: int, new_best: bool) -> void:
	show_message("GAME OVER", 1.6, PINK)
	sub_message.text = "score %d%s" % [score, "   NEW BEST!" if new_best else "   best %d" % best]
	sub_message.show()
	sub_message.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(sub_message, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.4)
	tw.tween_property(sub_message, "modulate:a", 0.0, 0.3)
	tw.tween_callback(sub_message.hide)


func update_score(value: int, pop := false) -> void:
	score_label.text = str(value)
	if pop:
		score_label.pivot_offset = score_label.size / 2
		score_label.scale = Vector2(1.45, 1.45)
		create_tween().tween_property(score_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_lives(n: int) -> void:
	lives = n
	lives_bar.pivot_offset = Vector2(0, 12)
	lives_bar.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(lives_bar, "scale", Vector2.ONE, 0.3)


func flash_screen(color: Color, strength := 0.6, time := 0.25) -> void:
	flash_rect.color = Color(color, strength)
	var tw := create_tween().set_ignore_time_scale(true)  # fade in real time, even during hit-stop
	tw.tween_property(flash_rect, "color:a", 0.0, time).set_ease(Tween.EASE_OUT)


func _draw_lives() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 3:
		var c := Vector2(14 + i * 30, 14)
		if i < lives:
			var p := 1.0 + 0.1 * sin(t * 4.0 + i)
			lives_bar.draw_circle(c, 13.0 * p, Color(MINT, 0.15))
			lives_bar.draw_circle(c, 8.0 * p, MINT)
			lives_bar.draw_circle(c + Vector2(-2.5, -2.5), 2.5, Color.WHITE)
		else:
			lives_bar.draw_arc(c, 8.0, 0.0, TAU, 20, Color(MINT, 0.35), 2.0, true)
