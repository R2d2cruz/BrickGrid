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

signal moto_destruida(es_ia: bool, color: String)

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
			probabilidad_error = 0.15 
		"normal":
			distancia_vision = 6
			probabilidad_error = 0.02 
		"dificil":
			distancia_vision = 12
			probabilidad_error = 0.0  
		
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
		
	if cooldown_ia > 0:
		cooldown_ia -= delta
		
	var giro = 0
	
	if es_ia:
		if cooldown_ia <= 0:
			giro = _pensar_ia()
	else:
		if Input.is_action_just_pressed(input_right):
			giro = 90
		elif Input.is_action_just_pressed(input_left):
			giro = -90
			
	if giro != 0:
		_pintar_estela()
		
		var futura_pos = frontWheel.global_position + (Vector2.UP.rotated(rotation + deg_to_rad(giro)) * TILE_SIZE)
		if tile_map and _es_celda_ocupada(tile_map.local_to_map(tile_map.to_local(futura_pos))):
			_explotar() 
			return
		
		newBack = frontWheel.global_position
		rotation_degrees += giro
		global_position = newBack + (global_position - backWheel.global_position)
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		
		if es_ia:
			# Multiplicado por 1.1: Obligamos a la moto a cruzar toda la celda antes de volver a girar
			cooldown_ia = (float(TILE_SIZE) / SPEED) * 1.1
			
		_pintar_estela()

@warning_ignore("unassigned_variable")
func _physics_process(delta: float) -> void:
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

func _explotar():
	esta_viva = false
	moto_destruida.emit(es_ia, color_moto)
	if motocycle:
		motocycle.visible = false
	if explotion:
		explotion.visible = true
		explotion.play()

func _on_explosion_terminada():
	if tile_map:
		for celda in celdas_pintadas:
			tile_map.set_cell(celda, -1)
	celdas_pintadas.clear()
	queue_free()

func _pintar_estela():
	if not tile_map: 
		return
	
	var pos_local = tile_map.to_local(backWheel.global_position)
	var celda_actual = tile_map.local_to_map(pos_local)
	
	if celda_actual != ultima_celda and ultima_celda != Vector2i.MAX:
		var id_del_atlas = color_a_id[color_moto]
		var celda_a_pintar = ultima_celda
		
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
				
# --- FUNCIONES DE INTELIGENCIA ARTIFICIAL (NIVEL DIOS - ÁREA VORONOI) ---

func _pensar_ia() -> int:
	if not tile_map: return 0
	
	var direccion_actual = Vector2.UP.rotated(rotation).round()
	var pos_inicio = frontWheel.global_position
	
	var dist_frente = _medir_distancia_libre(pos_inicio, direccion_actual, 5)
	
	var dir_izq = direccion_actual.rotated(deg_to_rad(-90)).round()
	var dir_der = direccion_actual.rotated(deg_to_rad(90)).round()

	# 1. MODO PÁNICO: El muro está inminentemente cerca (< 1.8 tiles). ¡Fuerza el giro!
	if dist_frente < 1.8:
		var area_izq = _medir_area_disponible(pos_inicio, dir_izq, 50)
		var area_der = _medir_area_disponible(pos_inicio, dir_der, 50)
		
		if area_izq > area_der: return -90
		elif area_der > area_izq: return 90
		# Si ambas son iguales (incluso 0 porque está acorralada), elige al azar para no morir recta
		elif randf() > 0.5: return 90
		else: return -90

	# 2. MODO EVASIÓN TEMPRANA: Ve el muro acercándose (< 4.0 tiles)
	elif dist_frente < 4.0:
		var area_frente = _medir_area_disponible(pos_inicio, direccion_actual)
		var area_izq = _medir_area_disponible(pos_inicio, dir_izq)
		var area_der = _medir_area_disponible(pos_inicio, dir_der)
		
		# Penalizamos el frente al 70% porque sabemos que tarde o temprano se acaba
		var mayor_area = max(area_frente * 0.7, max(area_izq, area_der))
		
		if mayor_area == area_izq and area_izq > 0: return -90
		elif mayor_area == area_der and area_der > 0: return 90
		else: return 0 
			
	# 3. MODO CAZA ESTRATÉGICO
	elif dificultad_ia == "dificil" and randf() < 0.1: 
		var presa = _buscar_presa()
		if presa:
			var dir_hacia_presa = (presa.global_position - pos_inicio).normalized()
			var dot_izq = dir_izq.dot(dir_hacia_presa)
			var dot_der = dir_der.dot(dir_hacia_presa)
			
			var area_frente = _medir_area_disponible(pos_inicio, direccion_actual, 100)
			
			if dot_izq > 0.5:
				if _medir_distancia_libre(pos_inicio, dir_izq, 4) >= 3.5 and _medir_area_disponible(pos_inicio, dir_izq, 100) >= (area_frente * 0.4):
					return -90
			elif dot_der > 0.5:
				if _medir_distancia_libre(pos_inicio, dir_der, 4) >= 3.5 and _medir_area_disponible(pos_inicio, dir_der, 100) >= (area_frente * 0.4):
					return 90

	return 0

func _medir_area_disponible(pos_inicio: Vector2, direccion: Vector2, limite_busqueda: int = 150) -> int:
	var pos_local = tile_map.to_local(pos_inicio + (direccion * TILE_SIZE))
	var celda_inicial = tile_map.local_to_map(pos_local)
	
	if _es_celda_ocupada(celda_inicial):
		return 0 
		
	var celdas_por_visitar = [celda_inicial]
	var celdas_visitadas = {celda_inicial: true}
	var area = 0
	
	var direcciones_vecinas = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	
	while celdas_por_visitar.size() > 0 and area < limite_busqueda:
		var celda_actual = celdas_por_visitar.pop_front()
		area += 1
		
		for dir in direcciones_vecinas:
			var vecina = celda_actual + dir
			
			if not celdas_visitadas.has(vecina):
				if not _es_celda_ocupada(vecina):
					celdas_visitadas[vecina] = true
					celdas_por_visitar.append(vecina)
					
	return area

func _es_celda_ocupada(celda: Vector2i) -> bool:
	if tile_map.get_cell_source_id(celda) != -1: return true
	if border_map.get_cell_source_id(celda) != -1: return true
	
	var posicion_global_celda = tile_map.to_global(tile_map.map_to_local(celda))
	var parent = get_parent()
	if parent:
		for otra_moto in parent.get_children():
			if otra_moto != self and otra_moto.get("esta_viva"):
				# Espacio personal más amplio (1.5 tiles)
				if posicion_global_celda.distance_to(otra_moto.global_position) < (TILE_SIZE * 1.5):
					return true
					
	return false

func _medir_distancia_libre(origen: Vector2, direccion: Vector2, max_distancia_tiles: int) -> float:
	var max_distancia_px = max_distancia_tiles * TILE_SIZE
	var space_state = get_world_2d().direct_space_state
	
	# REDUCIDO DE 0.4 A 0.2: Los rayos laterales ya no rozarán las paredes paralelas
	var offset_lateral = direccion.rotated(PI/2) * (TILE_SIZE * 0.2) 
	
	var origenes_rayos = [
		origen, 
		origen + offset_lateral,
		origen - offset_lateral
	]
	
	var menor_distancia = float(max_distancia_tiles)
	
	for punto_disparo in origenes_rayos:
		var destino = punto_disparo + (direccion * max_distancia_px)
		var query = PhysicsRayQueryParameters2D.create(punto_disparo, destino)
		query.exclude = [self.get_rid()] 
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var dist_choque = punto_disparo.distance_to(result.position) / TILE_SIZE
			if dist_choque < menor_distancia:
				menor_distancia = dist_choque
				
	return menor_distancia

func _buscar_presa() -> CharacterBody2D:
	var parent = get_parent()
	if not parent: return null
	
	var objetivo = null
	var menor_distancia = 99999.0
	
	for moto in parent.get_children():
		if moto != self and moto.get("esta_viva") and moto.get("es_ia") == false:
			var dist = global_position.distance_to(moto.global_position)
			if dist < menor_distancia:
				menor_distancia = dist
				objetivo = moto
				
	return objetivo
