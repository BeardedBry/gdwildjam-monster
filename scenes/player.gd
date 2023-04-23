class_name Player
extends CharacterBody3D

## Character maximum run speed on the ground.
@export var move_speed := 8.0
## Forward impulse after a melee attack.
@export var attack_impulse := 10.0
## Movement acceleration (how fast character achieve maximum speed)
@export var acceleration := 4.0
## Jump impulse
@export var jump_initial_impulse := 10.0
## Jump impulse when player keeps pressing jump
@export var jump_additional_force := 4.5
## Player model rotaion speed
@export var rotation_speed := 12.0
## Minimum horizontal speed on the ground. This controls when the character's animation tree changes 
## between the idle and running states.
@export var stopping_speed := 1.0
## Max throwback force after player takes a hit
@export var max_throwback_force := 15.0

@onready var _rotation_root: Node3D = $Armature
@onready var _camera_controller: CameraController = $CameraController
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _ground_shapecast: ShapeCast3D = $GroundShapeCast

@onready var _move_direction := Vector3.ZERO
@onready var _last_strong_direction := Vector3.FORWARD
@onready var _gravity: float = -30.0
@onready var _ground_height: float = 0.0
@onready var _start_position := global_transform.origin
@onready var _is_on_floor_buffer := false
@onready var _attacking := false



func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.setup(self)


func _physics_process(delta: float) -> void:
	# Calculate ground height for camera controller
	if _ground_shapecast.get_collision_count() > 0:
		for collision_result in _ground_shapecast.collision_result:
			_ground_height = max(_ground_height, collision_result.point.y)
	else:
		_ground_height = global_position.y + _ground_shapecast.target_position.y
	if global_position.y < _ground_height:
		_ground_height = global_position.y

	# Get input and movement state
	var is_just_attacking := Input.is_action_just_pressed("attack")
	var is_just_jumping := Input.is_action_just_pressed("ui_accept") and is_on_floor()
	var is_air_boosting := Input.is_action_pressed("ui_accept") and not is_on_floor() and velocity.y > 0.0

	_is_on_floor_buffer = is_on_floor()
	_move_direction = _get_camera_oriented_input()

	# To not orient quickly to the last input, we save a last strong direction,
	# this also ensures a good normalized value for the rotation basis.
	if _move_direction.length() > 0.2:
		_last_strong_direction = _move_direction.normalized()

	_orient_character_to_direction(_last_strong_direction, delta)

	# We separate out the y velocity to not interpolate on the gravity
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.lerp(_move_direction * move_speed, acceleration * delta)
	if _move_direction.length() == 0 and velocity.length() < stopping_speed:
		velocity = Vector3.ZERO
	velocity.y = y_velocity

	_camera_controller.set_pivot(_camera_controller.CAMERA_PIVOT.THIRD_PERSON)

	# Update attack state and position
	if is_just_attacking:
		pass
#		attack()
	else:
		velocity.y += _gravity * delta

	if is_just_jumping:
		velocity.y += jump_initial_impulse
	elif is_air_boosting:
		velocity.y += jump_additional_force * delta

	# Set character animation
	if is_just_jumping:
		_animation_player.play("bigfoot/Jump")
#	elif not is_on_floor() and velocity.y < 0:
#		_animation_player.play("bigfoot/Fall")
	elif is_on_floor():
		var xz_velocity := Vector3(velocity.x, 0, velocity.z)
		if _attacking == false:
			if xz_velocity.length() > stopping_speed:
				_animation_player.play("bigfoot/Run")
			else:
				_animation_player.play("bigfoot/Idle")

	var position_before := global_position
	move_and_slide()
	var position_after := global_position

	# If velocity is not 0 but the difference of positions after move_and_slide is,
	# character might be stuck somewhere!
	var delta_position := position_after - position_before
	var epsilon := 0.001
	if delta_position.length() < epsilon and velocity.length() > epsilon:
		global_position += get_wall_normal() * 0.1


func attack() -> void:
	_animation_player.play("bigfoot/Attack")
	_attacking = true


func reset_position() -> void:
	transform.origin = _start_position


func _get_camera_oriented_input() -> Vector3:
	var raw_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var input := Vector3.ZERO
	# This is to ensure that diagonal input isn't stronger than axis aligned input
	input.x = -raw_input.x * sqrt(1.0 - raw_input.y * raw_input.y / 2.0)
	input.z = -raw_input.y * sqrt(1.0 - raw_input.x * raw_input.x / 2.0)

	input = _camera_controller.global_transform.basis * input
	input.y = 0.0
	return input


func _orient_character_to_direction(direction: Vector3, delta: float) -> void:
	var left_axis := Vector3.UP.cross(direction)
	var rotation_basis := Basis(left_axis, Vector3.UP, direction).get_rotation_quaternion()
	var model_scale := _rotation_root.transform.basis.get_scale()
	_rotation_root.transform.basis = Basis(
		_rotation_root.transform.basis.get_rotation_quaternion()
			.slerp(rotation_basis, delta * rotation_speed)
	).scaled(model_scale)
