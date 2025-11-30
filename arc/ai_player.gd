extends AIController3D

var episode_reward: float=0.0 
var episode_steps: int=0
var max_episode_steps: int =1000

var last_distance_to_enemy: float =999.0
var time_alive: float = 0.0 
var hits_taken: int = 0

func get_obs() -> Dictionary:
	var player = get_parent()
	var enemies = get_tree().get_nodes_in_group('enemies')
	var closest_enemy = null 
	var min_distance = 999999.0
	
	for enemy in enemies:
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist < min_distance:
			min_distance = dist 
			closest_enemy = enemy
		
	var obs = []
		
	obs.append(player.global_position.x/20.0)
	obs.append(player.global_position.z/20.0)
	obs.append(player.velocity.x/5.0)
	obs.append(player.velocity.z/5.0)
		
	if closest_enemy:
		var rel_pos = closest_enemy.global_position - player.global_position
		obs.append(clamp(rel_pos.x/40.0, -1.0, 1.0))
		obs.append(clamp(rel_pos.z/40.0, -1.0, 1.0))
		obs.append(clamp(min_distance/40.0, 0.0, 1.0))
			
		obs.append(closest_enemy.velocity.x/6.0)
		obs.append(closest_enemy.velocity.z/6.0)
		obs.append(1.0 if check_line_of_sight(player, closest_enemy)else 0.0)
	else:
		for i in range(6):
			obs.append(0.0)
		
	var projectiles = get_tree().get_nodes_in_group('projectiles')
	var sorted_projectiles = []
		
	for proj in projectiles:
		var p_dist = player.global_position.distance_to(proj.global_position)
		sorted_projectiles.append({
			'proj':proj,
			'dist':p_dist
		})
			
	sorted_projectiles.sort_custom(func(a,b): return a.dist<b.dist)
			
	for i in range(2):
		if i < sorted_projectiles.size():
			var proj = sorted_projectiles[i].proj
			var rel_pos = proj.global_position - player.global_position
			obs.append(clamp(rel_pos.x/20.0, -1.0, 1.0))
			obs.append(clamp(rel_pos.z/20.0, -1.0, 1.0))
					
			if 'direction' in proj:
				obs.append(proj.direction.x)
				obs.append(proj.direction.z)
						
			else:
				obs.append(0.0)
				obs.append(0.0)
		else:
			for j in range(5):
				obs.append(0.0)
	var angles = [0, PI/4, PI/2, 3*PI/4, PI, 5*PI, 3*PI/2, 7*PI/4]
	for angle in angles:
		var dir = Vector3(cos(angle), 0, sin(angle))
		var distance = cast_ray_distance(player, dir, 20.0)
		obs.append(clamp(distance/ 20.0, 0.0, 1.0))
			
	return {'obs': obs}
	
	
func get_reward()->float:
	var r = reward 
	reward =0.0
	return r 

func get_action_space()->Dictionary:
	return {
		'move': {
			'size': 2,
			'action_type': 'continuous'
		}
	} 
	 
func set_action(action) ->void:
	var player = get_parent()
	var move_x = clamp(action.move[0], -1.0, 1.0)
	var move_z = clamp(action.move[1], -1.0, 1.0)
	
	player.ai_move_x = move_x 
	player.ai_move_z = move_z  
	
func check_line_of_sight(from_node: Node3D, to_node: Node3D)->bool:
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from_node.global_position + Vector3(0,1,0)
	query.to = to_node.global_position + Vector3(0,1,0)
	query.exclude =[from_node] 
	
	var space_state = from_node.get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == to_node:
		return true
	return false 

func cast_ray_distance(from_node: Node3D, direction:Vector3, max_distance: float)->float:
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from_node.global_position + Vector3(0, 0.5, 0)
	query.to = from_node.global_position + direction * max_distance
	query.exclude = [from_node]
	
	var space_state = from_node.get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	
	if result:
		return from_node.global_position.distance_to(result.position)
	return max_distance 

func calculate_step_reward(delta: float):
	var player = get_parent()
	episode_steps += 1
	time_alive += delta
	
	reward += 0.1 * delta 
	
	var enemies = get_tree().get_nodes_in_group('enemies')
	if enemies.size() > 0:
		var closest_enemy = enemies[0]
		var min_distance = 999999.0
		
		for enemy in enemies:
			var dist = player.global_position.distance_to(enemy.global_position)
			if dist < min_distance:
				min_distance = dist 
				closest_enemy = enemy 
			if min_distance > 8.0 and min_distance < 15.0:
				reward += 0.2 * delta 
			elif min_distance < 5.0:
				reward -= 0.1 * delta 
			elif min_distance > 20.0:
				reward -=0.05 * delta 
			
			
			var distance_change = min_distance - last_distance_to_enemy
			if min_distance < 8.0 and distance_change > 0:
				reward += 0.3 * delta 
			last_distance_to_enemy = min_distance
			
			var has_los = check_line_of_sight(closest_enemy, player)
			if not has_los and min_distance<15.0:
				reward += 0.3 * delta 
		
		var wall_distances = []
		var angles = [0, PI/4, PI/2, 3*PI/4, PI, 5*PI/4, 3*PI/2, 7*PI/4]
		for angle in angles:
			var direction = Vector3(cos(angle), 0, sin(angle))
			var distance = cast_ray_distance(player, direction, 20.0)
			wall_distances.append(distance)
		
		var min_wall_dist = wall_distances.min()
		if min_wall_dist<2.0:
			reward -= 0.05 * delta 
		
		var speed = player.velocity.length()
		if speed <0.5:
			reward -=0.1 * delta 
	
func on_hit_by_projectile()->void:
	reward -=5.0
	hits_taken += 1
	#print("Player hit! Total hits: ", hits_taken, " Reward: ", reward)
		
	if hits_taken >=3:
		done=true 
		needs_reset = true 
		reward -=10.0

func on_episode_timeout()->void:
	reward += 10.0
	done = true
	needs_reset = true 
	print("Episode complete! Survived full duration. Final reward: ", reward)

func reset()->void:
	super.reset()
	reward=0.0
	episode_steps=0
	time_alive=0.0
	hits_taken=0
	last_distance_to_enemy= 999.0
	done=false 
	needs_reset=false
	
	var player = get_parent()
	player.reset_player()
	
	print('Episode reset')
