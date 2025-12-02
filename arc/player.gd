extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var gravity: float = -9.8
@export var mouse_sensitivity: float = 0.003
@export var health: int = 8
@export var is_training: bool = false  # Set to true when training with AI

var pitch: float = 0.0
var ai_move_x: float = 0.0
var ai_move_z: float = 0.0

@onready var ai_controller = $AIController3D

func _ready():	
	if not is_training:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event):
	if not is_training and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80), deg_to_rad(80))
		$SpringArm3D.rotation.x = pitch  
		
func _physics_process(delta):
	var input_dir = Vector3.ZERO 
	
	if is_training:
		# AI CONTROL MODE
		# Convert AI actions to world space movement (no camera rotation)
		input_dir.x = ai_move_x
		input_dir.z = ai_move_z
		
		if Engine.get_physics_frames()%60==0:
						print("AI Actions: x=", ai_move_x, " z=", ai_move_z, " | Velocity: ", velocity)
					
		# Calculate rewards
		if ai_controller:
			ai_controller.calculate_step_reward(delta)
			
	else:
		# MANUAL CONTROL MODE (your existing code)
		if Input.is_action_pressed('move_forward'):
			input_dir -= transform.basis.z
		if Input.is_action_pressed('move_back'):
			input_dir += transform.basis.z
		if Input.is_action_pressed('move_left'):
			input_dir -= transform.basis.x
		if Input.is_action_pressed('move_right'):
			input_dir += transform.basis.x
	
	input_dir = input_dir.normalized()
	
	# Horizontal movement
	velocity.x = input_dir.x * speed 
	velocity.z = input_dir.z * speed 
	
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta 
	else:
		velocity.y = 0
		# Disable jump during training (agent should focus on dodging)
		if not is_training and Input.is_action_just_pressed('jump'):
			velocity.y = jump_velocity
	
	move_and_slide()
	
	# Check episode timeout
	if is_training and ai_controller and ai_controller.episode_steps >= ai_controller.max_episode_steps:
		ai_controller.on_episode_timeout()

func take_damage():
	health -= 1
	print("Player hit! Health remaining: ", health)
	
	if ai_controller:
		ai_controller.on_hit_by_projectile()
	
	if health <= 0:
		print('Player Died')
		reset_player()

func reset_player():
	health = 8
	var spawn_angle = randf() * TAU 
	var spawn_dist = randf_range(8.0, 15.0)
	global_position = Vector3(
		cos(spawn_angle)*spawn_dist, 
		1, 
		sin(spawn_angle)*spawn_dist) 
	velocity = Vector3.ZERO
	print("Player reset!")
