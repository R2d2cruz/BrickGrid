extends CharacterBody2D

@export var frontWheel: Node2D
@export var backWheel: Node2D

@export_enum("red", "blue", "green", "yellow", "orange", "white") var color_moto: String = "blue"

@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D

var newBack: Vector2
const SPEED = 2000.0

func _ready():
	if sprite_animado:
		sprite_animado.play(color_moto)

func _process(delta):
	# --- CONTROL DE ROTACIÓN CLÁSICO (TRON) ---
	
	# Detecta el instante exacto en que se presiona la tecla a la derecha
	if Input.is_action_just_pressed("ui_right"):
		newBack = frontWheel.global_position
		rotation_degrees += 90
		global_position = newBack + (global_position - backWheel.global_position)
		
	# Detecta el instante exacto en que se presiona la tecla a la izquierda
	elif Input.is_action_just_pressed("ui_left"):
		newBack = frontWheel.global_position
		rotation_degrees -= 90
		global_position = newBack + (global_position - backWheel.global_position)

func _physics_process(delta: float) -> void:
	velocity = Vector2.UP.rotated(rotation) * SPEED
	velocity.x = round(velocity.x)
	velocity.y = round(velocity.y)
	move_and_slide()
