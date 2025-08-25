extends CharacterBody2D

signal place_shape(global_pos : Vector2, curve : Curve2D)
signal cut_shapes(global_pos : Vector2, curve : Curve2D)

const SPEED := 500.0
const JUMP_VELOCITY = -300.0

var dead := false
var bumped_into_wall := false
var target : Node2D = null
@onready var orig_pos := position

func _ready() -> void:
	$AnimationPlayer.play("run")
	$ShapeHintEllipse.visible = false
	$ShapeHintRectangle.visible = true

func _process(delta: float) -> void:
	var global_mouse_pos := get_global_mouse_position()
	$ShapeHintEllipse.global_position = global_mouse_pos
	$ShapeHintRectangle.global_position = global_mouse_pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not event.pressed:
			$ShapeHintEllipse.visible = not $ShapeHintEllipse.visible
			$ShapeHintRectangle.visible = not $ShapeHintRectangle.visible

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cur_shape : ScalableVectorShape2D = $ShapeHintEllipse if $ShapeHintEllipse.visible else $ShapeHintRectangle
			place_shape.emit(get_global_mouse_position(), cur_shape.curve)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var cur_shape : ScalableVectorShape2D = $ShapeHintEllipse if $ShapeHintEllipse.visible else $ShapeHintRectangle
			cut_shapes.emit(get_global_mouse_position(), cur_shape.curve)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta * 3
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
	else:
		velocity.x = SPEED if $Pivot.scale.x > 0 else -SPEED
	move_and_slide()
	if bumped_into_wall:
		bumped_into_wall = false
		$Pivot.scale.x = -$Pivot.scale.x
	elif is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY


func _on_wall_detector_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		bumped_into_wall = true


func die() -> void:
	dead = true
	$AnimationPlayer.play("disappear")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "disappear":
		position = orig_pos
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		$AnimationPlayer.play("run")
		dead = false
		velocity = Vector2.ZERO
