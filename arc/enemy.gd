extends CharacterBody3D

@export var speed: float = 4.0 
@export var shooting_range: float =  9.0
@export var shoot_cooldown_sec: float = 1.0
@export var roam_radius: float = 15.0
@export var roam_speed_mult: float = 0.4
@export var gravity: float = -9.8
@export var fov_angle: float = 162.0
@export var projectile_scene: PackedScene 
@export var show_fov_debug: bool = false 

var player: Node3D
var can_shoot: bool = true 
var roam_center: Vector3
var roam_target: Vector3  
var roaming: bool = true  
var player_in_range:bool = false 
var has_line_of_sight: bool = false
var last_known_player_position: Vector3 = Vector3.ZERO
var investigating: bool = false 
var fov_mesh: MeshInstance3D
@export var investigation_pause_duration: float = 3.0

@onready var detection = $Area3D
@onready var cooldown = $shoot_cooldown

func _ready():
	player = get_tree().get_root().find_child("Players", true, false)
	roam_center = global_transform.origin 
	pick_new_roam_target2()
	
	detection.body_entered.connect(_on_body_entered)
	detection.body_exited.connect(_on_body_exited)
	
	cooldown.wait_time = shoot_cooldown_sec
	cooldown.one_shot = false  
	cooldown.timeout.connect(_on_shoot_cooldown_timeout)
	cooldown.start()
	
	create_fov_visualization()

func create_fov_visualization():
	fov_mesh = MeshInstance3D.new()
	add_child(fov_mesh)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 0, 0.3)  # Yellow, semi-transparent
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	fov_mesh.material_override = material
	
	update_fov_mesh()

func update_fov_mesh():
	if not show_fov_debug:
		if fov_mesh:
			fov_mesh.visible = false
		return
	
	if fov_mesh:
		fov_mesh.visible = true
	
	# Get the detection radius from Area3D's CollisionShape3D
	var detection_radius = 10.0  # Default fallback
	if detection and detection.get_child_count() > 0:
		var collision_shape = detection.get_child(0) as CollisionShape3D
		if collision_shape and collision_shape.shape is SphereShape3D:
			detection_radius = collision_shape.shape.radius
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Center point (enemy position)
	verts.append(Vector3.ZERO)
	
	# Create arc for FOV using detection radius
	var segments = 32
	var half_fov = deg_to_rad(fov_angle / 2.0)
	
	for i in range(segments + 1):
		var angle = -half_fov + (half_fov * 2.0 * i / segments)
		var x = sin(angle) * detection_radius
		var z = -cos(angle) * detection_radius
		verts.append(Vector3(x, 0.5, z))  # Slight Y offset so it's visible above ground
	
	# Create triangles
	for i in range(segments):
		indices.append(0)  # Center
		indices.append(i + 1)
		indices.append(i + 2)
	
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	fov_mesh.mesh = arr_mesh
	
func _physics_process(delta):
	if not player:
		return 
	var to_player = player.global_transform.origin - global_transform.origin
	var distance = to_player.length()
	
	has_line_of_sight=check_line_of_sight_with_fov()
	
	if has_line_of_sight and player_in_range:
		last_known_player_position = player.global_transform.origin
		roaming=false
		investigating=false
		
		look_at(player.global_transform.origin, Vector3.UP)
		
		if distance > shooting_range:
			var dir = to_player.normalized()
			velocity.x = dir.x * speed 
			velocity.z = dir.z * speed 
			
		else:
			velocity.x = 0
			velocity.z = 0
			if can_shoot:
				shoot_player()
	elif investigating:
		handle_investigation()
		
	else:
		roaming=true
		handle_roam_state()
		
	if not is_on_floor():
		velocity.y += gravity * delta 
	move_and_slide()
	
	if show_fov_debug and fov_mesh:
		var mat = fov_mesh.material_override as StandardMaterial3D
		if has_line_of_sight and player_in_range:
			var to_player_dist = (player.global_transform.origin - global_transform.origin).length()
			if to_player_dist <= shooting_range and can_shoot:
				mat.albedo_color = Color(1, 0, 0, 0.3)  # Red when shooting
			else:
				mat.albedo_color = Color(1, 1, 0, 0.3)  # Yellow when chasing
		elif investigating:
			mat.albedo_color = Color(1, 0.5, 0, 0.3)  # Orange when investigating
		else:
			mat.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
		
func check_line_of_sight_with_fov():
	if not player or not player_in_range:
		return false 
	var to_player = (player.global_transform.origin - global_transform.origin)
	var forward = -global_transform.basis.z.normalized()
	
	var angle_to_player = rad_to_deg(acos(forward.dot(to_player)))
	
	if angle_to_player > fov_angle/2.0:
		#print("Player outside FOV (angle: ", angle_to_player, ")")
		return false 
	var query = PhysicsRayQueryParameters3D.new()
	query.from = global_transform.origin + Vector3(0, 0.6, 0)
	query.to = player.global_transform.origin + Vector3(0, 0.6, 0)
	
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == player:
			return true 
		else:
			#print("Line of sight blocked by: ", result.collider.name)
			return false
	else:
		return true 
		
#func check_line_of_sight():
	#if not player:
		#return false 
	#var query = PhysicsRayQueryParameters3D.new()
	#query.from = global_transform.origin + Vector3(0, 0.6, 0)
	#query.to = player.global_transform.origin + Vector3(0, 0.6, 0)
	#query.exclude = [self]
	#
	#var space_state = get_world_3d().direct_space_state
	#var result = space_state.intersect_ray(query)
	#
	#if result:
		#if result.collider == player:
			#return true 
		#else:
			#print('Line of sight blocked by: ', result.collider.name)
			#return false 
	#else:
		#return true

func handle_investigation():
	var to_last_position = last_known_player_position - global_transform.origin 
	to_last_position.y = 0
	var distance_to_last = to_last_position.length()
	#print("Investigating! Distance to last position: ", distance_to_last)
	
	if distance_to_last < 2.0:
		#print("Reached last known position, resuming roaming")
		investigating = false
		roaming = true
		pick_new_roam_target2()
		return
	
	look_at(last_known_player_position, Vector3.UP)
	var dir = to_last_position.normalized()
	velocity.x = dir.x * speed * 0.8 
	velocity.z = dir.z * speed * 0.8 
	
	if get_slide_collision_count() > 0:
		investigating = false 
		roaming=true 
		pick_new_roam_target2()
		return 
	
#func pick_new_roam_target():
	#var x = randf_range(-roam_radius, roam_radius)
	#var z = randf_range(-roam_radius, roam_radius)
	#roam_target = roam_center + Vector3(x, 0, z)
	#
func handle_roam_state():
	var to_target = roam_target - global_transform.origin 
	to_target.y = 0
	if to_target.length() < 1.0:
		pick_new_roam_target2()
		return

	# check blocked
	var query = PhysicsRayQueryParameters3D.new()
	query.from = global_transform.origin
	query.to = roam_target
	query.exclude = [self] 
	
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	
	if result:
		pick_new_roam_target2()
		return 
	
	look_at(roam_target, Vector3.UP)
	var dir = to_target.normalized()
	velocity.x = dir.x * speed * roam_speed_mult
	velocity.z = dir.z * speed * roam_speed_mult

		
func shoot_player():
	if can_shoot:
		#print('Bang!! shooting player')
		can_shoot = false 
		
		if projectile_scene and player:
			var proj = projectile_scene.instantiate()
		
			get_parent().add_child(proj)
			proj.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)	
			var shoot_direction = (player.global_transform.origin - global_transform.origin).normalized()
			proj.set_direction(shoot_direction)
			proj.look_at(player.global_transform.origin, Vector3.UP)
			#print("Projectile spawned!")
		
func _on_shoot_cooldown_timeout():
	can_shoot = true 

func _on_body_entered(body):
	if body == self or body != player:  # Only process if it's the player
		return 
	player_in_range = true 
	#print('Player detected')

func _on_body_exited(body):
	if body != player:  # Only process if it's the player
		return
	player_in_range = false
	#print('Player left range')
	if last_known_player_position != Vector3.ZERO:
		investigating=true 
		#print("Lost player, investigating last position: ", last_known_player_position)

# TODO: ensure that the raom radius is with the arena boudanry only to prevent wall stuck
func pick_new_roam_target2():
	var random_angle = randf() * TAU 
	var random_distance = randf_range(3.0, roam_radius)
	
	roam_target = roam_center + Vector3(
		cos(random_angle) * random_distance,
		0,
		sin(random_angle) * random_distance
	)
	#print('New roam target: ', roam_target)
