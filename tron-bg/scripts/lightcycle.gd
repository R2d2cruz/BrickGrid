extends CharacterBody2D

# Referencias a los nodos de la moto y el mapa
@export var frontWheel: Node2D
@export var backWheel: Node2D
@export var tile_map: TileMapLayer
@export var motocycle: AnimatedSprite2D
@export var explotion: AnimatedSprite2D


# Configuración visual
@export_enum("red", "blue", "green", "yellow", "orange", "white") var color_moto: String = "blue"
@export var grosor_estela: int = 4 # ¡Aumenta esto si quieres una línea mucho más gruesa!



# Variables de movimiento
var newBack: Vector2
const SPEED = 2000.0

# --- NUEVA VARIABLE DE ESTADO ---
var esta_viva: bool = true 

# Diccionario de colores
var color_a_id: Dictionary = {
	"blue": 1,
	"green": 2,
	"white": 3,
	"orange": 4,
	"red": 5,
	"yellow": 6
}

# --- VARIABLES DEL TILEMAP ---
var celdas_pintadas: Array[Vector2i] = []
var ultima_celda: Vector2i = Vector2i.MAX
var TILE_SIZE: int = 54 

func _ready():
	# 1. Nos aseguramos de ocultar la explosión al inicio
	if explotion:
		explotion.visible = false
		# Conectamos la señal que avisa cuando la animación de explosión termina
		explotion.animation_finished.connect(_on_explosion_terminada)
		
	if motocycle:
		motocycle.play(color_moto)
		
	if tile_map:
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		var pos_local = tile_map.to_local(backWheel.global_position)
		ultima_celda = tile_map.local_to_map(pos_local)
		_pintar_bloque_grueso(ultima_celda, color_a_id[color_moto])

func _process(delta):
	# Si ya explotó, no permitimos girar ni pintar más
	if not esta_viva:
		return
		
	var giro = 0
	
	if Input.is_action_just_pressed("ui_right"):
		giro = 90
	elif Input.is_action_just_pressed("ui_left"):
		giro = -90
		
	if giro != 0:
		_pintar_estela()
		
		newBack = frontWheel.global_position
		rotation_degrees += giro
		global_position = newBack + (global_position - backWheel.global_position)
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		
		_pintar_estela()

func _physics_process(delta: float) -> void:
	# Si la moto explotó, detenemos el avance físico
	if not esta_viva:
		return
		
	velocity = Vector2.UP.rotated(rotation) * SPEED
	velocity.x = round(velocity.x)
	velocity.y = round(velocity.y)
	
	# move_and_slide() devuelve 'true' si colisionó con algo en este frame
	var choco = move_and_slide()
	
	if choco:
		_explotar()
	else:
		_pintar_estela()

# --- NUEVAS FUNCIONES PARA LA DESTRUCCIÓN ---

func _explotar():
	esta_viva = false
	
	# Hacemos invisible la moto (uso ambos nodos por si acaso)
	if motocycle:
		motocycle.visible = false
		
	# Hacemos visible la explosión y la reproducimos
	if explotion:
		explotion.visible = true
		explotion.play() # Pon el nombre de tu animación entre comillas si no es "default", ej: play("boom")

func _on_explosion_terminada():
	# La animación terminó, así que borramos todas las celdas que pintó esta moto
	if tile_map:
		for celda in celdas_pintadas:
			# Poner el ID como -1 en un TileMapLayer significa "borrar"
			tile_map.set_cell(celda, -1)
			
	# Vaciamos la lista de celdas
	celdas_pintadas.clear()
	
	# Opcional: Si quieres que el nodo de la moto se elimine del juego por completo
	# descomenta la siguiente línea:
	queue_free()

# --------------------------------------------

func _pintar_estela():
	if not tile_map: 
		return
	
	var pos_local = tile_map.to_local(backWheel.global_position)
	var celda_actual = tile_map.local_to_map(pos_local)
	
	if celda_actual != ultima_celda and ultima_celda != Vector2i.MAX:
		var id_del_atlas = color_a_id[color_moto]
		var celda_a_pintar = ultima_celda
		
		# Rellenamos eje X
		while celda_a_pintar.x != celda_actual.x:
			celda_a_pintar.x += sign(celda_actual.x - celda_a_pintar.x)
			_pintar_bloque_grueso(celda_a_pintar, id_del_atlas)
			
		# Rellenamos eje Y
		while celda_a_pintar.y != celda_actual.y:
			celda_a_pintar.y += sign(celda_actual.y - celda_a_pintar.y)
			_pintar_bloque_grueso(celda_a_pintar, id_del_atlas)
			
		ultima_celda = celda_actual

func _pintar_bloque_grueso(celda_base: Vector2i, id_atlas: int):
	# Calcula la mitad para centrar el bloque en la coordenada
	var mitad = grosor_estela / 2
	
	# Crea un cuadrado perfecto de celdas basado en el tamaño de grosor_estela
	for x in range(-mitad, grosor_estela - mitad):
		for y in range(-mitad, grosor_estela - mitad):
			var celda_final = celda_base + Vector2i(x, y)
			
			tile_map.set_cell(celda_final, id_atlas, Vector2i(0, 0))
			# Evitamos llenar la lista de duplicados
			if not celdas_pintadas.has(celda_final):
				celdas_pintadas.append(celda_final)
