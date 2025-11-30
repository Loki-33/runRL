extends Area3D

@export var speed: float = 10.0
@export var lifetime: float = 3.0
var direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float) -> void:
	if direction != Vector3.ZERO:
		global_translate(direction * speed * delta)

func set_direction(dir: Vector3) -> void:
	direction = dir

func _on_body_entered(body):
	if body.is_in_group("players"):
		body.take_damage()
		queue_free()
	elif body.name != "Enemys":  # Hit a wall or obstacle
		queue_free()
