extends CharacterBody2D

# --- NUEVAS REFERENCIAS PARA LA IA ---
@export var border_map: TileMapLayer

@export var es_ia: bool = false
@export_enum("facil", "normal", "dificil") var dificultad_ia: String = "normal"

var distancia_vision: int = 6
var probabilidad_error: float = 0.0
var cooldown_ia: float = 0.0

# Referencias a los nodos de la moto y el mapa
@export var frontWheel: Node2D
@export var backWheel: Node2D
@export var tile_map: TileMapLayer
@export var motocycle: AnimatedSprite2D
@export var explotion: AnimatedSprite2D

# Configuración visual
@export_enum("red", "blue", "green", "yellow", "orange", "white") var color_moto: String = "blue"
@export var grosor_estela: int = 4

# --- NUEVAS VARIABLES PARA CONTROLES INDEPENDIENTES ---
var input_left: String = "ui_left"
var input_right: String = "ui_right"

# Variables de movimiento
var newBack: Vector2
const SPEED = 2000.0

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
	if explotion:
		explotion.visible = false
		explotion.animation_finished.connect(_on_explosion_terminada)
		
	if motocycle:
		motocycle.play(color_moto)
		
	_configurar_dificultad()

func _configurar_dificultad():
	if not es_ia: return
	
	match dificultad_ia:
		"facil":
			distancia_vision = 3
			probabilidad_error = 0.15 # 15% de probabilidad de no reaccionar a tiempo
		"normal":
			distancia_vision = 6
			probabilidad_error = 0.02 # Un margen de error muy pequeño
		"dificil":
			distancia_vision = 12
			probabilidad_error = 0.0  # Juego perfecto, ve muy lejos y no se equivoca
		
func configurar_inicio():
	if tile_map:
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		var pos_local = tile_map.to_local(backWheel.global_position)
		ultima_celda = tile_map.local_to_map(pos_local)
		_pintar_bloque_grueso(ultima_celda, color_a_id[color_moto])

@warning_ignore("unassigned_variable")
func _process(delta):
	if not esta_viva:
		return
		
	# Reducimos el temporizador de la IA
	if cooldown_ia > 0:
		cooldown_ia -= delta
		
	var giro = 0
	
	# Si es IA y puede pensar, decide si girar
	if es_ia:
		if cooldown_ia <= 0:
			giro = _pensar_ia()
	else:
		# Controles del jugador real
		if Input.is_action_just_pressed(input_right):
			giro = 90
		elif Input.is_action_just_pressed(input_left):
			giro = -90
			
	if giro != 0:
		_pintar_estela()
		
		newBack = frontWheel.global_position
		rotation_degrees += giro
		global_position = newBack + (global_position - backWheel.global_position)
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		
		# Le damos un respiro a la IA después de girar
		if es_ia:
			cooldown_ia = 0.15 
			
		_pintar_estela()

@warning_ignore("unassigned_variable")
func _physics_process(delta: float) -> void:
	# Si la moto explotó, detenemos el avance físico
	if not esta_viva:
		return
		
	velocity = Vector2.UP.rotated(rotation) * SPEED
	velocity.x = round(velocity.x)
	velocity.y = round(velocity.y)
	
	var choco = move_and_slide()
	
	if choco:
		_explotar()
	else:
		_pintar_estela()

# --- NUEVAS FUNCIONES PARA LA DESTRUCCIÓN ---

func _explotar():
	esta_viva = false
	if motocycle:
		motocycle.visible = false
	if explotion:
		explotion.visible = true
		explotion.play()

func _on_explosion_terminada():
	# La animación terminó, así que borramos todas las celdas que pintó esta moto
	if tile_map:
		for celda in celdas_pintadas:
			# Poner el ID como -1 en un TileMapLayer significa "borrar"
			tile_map.set_cell(celda, -1)
	celdas_pintadas.clear()

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
			
		while celda_a_pintar.y != celda_actual.y:
			celda_a_pintar.y += sign(celda_actual.y - celda_a_pintar.y)
			_pintar_bloque_grueso(celda_a_pintar, id_del_atlas)
			
		ultima_celda = celda_actual

func _pintar_bloque_grueso(celda_base: Vector2i, id_atlas: int):
	var mitad = grosor_estela / 2
	for x in range(-mitad, grosor_estela - mitad):
		for y in range(-mitad, grosor_estela - mitad):
			var celda_final = celda_base + Vector2i(x, y)
			tile_map.set_cell(celda_final, id_atlas, Vector2i(0, 0))
			if not celdas_pintadas.has(celda_final):
				celdas_pintadas.append(celda_final)
				
# --- FUNCIONES DE INTELIGENCIA ARTIFICIAL ---

func _pensar_ia() -> int:
	if not tile_map: return 0
	
	var direccion_actual = Vector2.UP.rotated(rotation).round()
	
	# NUEVO: Empezamos a medir desde la rueda delantera
	var pos_inicio = frontWheel.global_position
	
	if _hay_peligro(pos_inicio, direccion_actual, distancia_vision):
		# Simulamos el error humano/retraso en los reflejos
		if randf() < probabilidad_error:
			return 0 # Sigue derecho este frame (puede que se estrelle o gire en el siguiente)
			
		var dir_izquierda = direccion_actual.rotated(deg_to_rad(-90)).round()
		var dir_derecha = direccion_actual.rotated(deg_to_rad(90)).round()
		
		var espacio_izq = _medir_espacio(pos_inicio, dir_izquierda)
		var espacio_der = _medir_espacio(pos_inicio, dir_derecha)
		
		if espacio_izq > espacio_der:
			return -90
		elif espacio_der > espacio_izq:
			return 90
		else:
			return 90 if randi() % 2 == 0 else -90
			
	return 0

func _hay_peligro(pos_inicio: Vector2, direccion: Vector2, distancia: int) -> bool:
	for i in range(1, distancia + 1):
		var pos_futura = pos_inicio + (direccion * i * TILE_SIZE)
		if _es_obstaculo(pos_futura):
			return true
	return false

func _medir_espacio(pos_inicio: Vector2, direccion: Vector2) -> int:
	var espacio = 0
	for i in range(1, 20):
		var pos_futura = pos_inicio + (direccion * i * TILE_SIZE)
		if _es_obstaculo(pos_futura):
			break 
		espacio += 1
	return espacio

func _es_obstaculo(posicion_global: Vector2) -> bool:
	# 1. Revisamos el mapa de estelas
	if tile_map:
		var pos_local = tile_map.to_local(posicion_global)
		var celda = tile_map.local_to_map(pos_local)
		if tile_map.get_cell_source_id(celda) != -1:
			return true
			
	# 2. Revisamos el mapa de los bordes/paredes
	if border_map:
		var pos_local_borde = border_map.to_local(posicion_global)
		var celda_borde = border_map.local_to_map(pos_local_borde)
		if border_map.get_cell_source_id(celda_borde) != -1:
			return true
			
	return false
