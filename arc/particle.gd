extends Area3D

@export var speed: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if direction != Vector3.ZERO:
		global_translate(direction * speed * delta)
		
