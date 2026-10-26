extends Sprite2D

@export var distance: float = 300.0
@export var duration: float = 0.5

var start_position: Vector2
var tween: Tween
var is_moving: bool = false

func _ready() -> void:
	start_position = position

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_K) and not Input.is_key_label_pressed(KEY_NONE):
		pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_K and event.pressed and not event.echo:
		toggle_movement()

func toggle_movement() -> void:
	is_moving = not is_moving

	if is_moving:
		tween = create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)

		tween.tween_property(self, "position:x", start_position.x + distance, duration)
		tween.tween_property(self, "position:x", start_position.x, duration)
	else:
		if tween:
			tween.kill()
		position = start_position
