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
		
		# --- PARCHE ANTI-GLITCH ---
		var futura_pos = frontWheel.global_position + (Vector2.UP.rotated(rotation + deg_to_rad(giro)) * TILE_SIZE)
		if tile_map and _es_celda_ocupada(tile_map.local_to_map(tile_map.to_local(futura_pos))):
			_explotar() # Intentó saltar un muro girando, la destruimos.
			return
		# --------------------------
		
		newBack = frontWheel.global_position
		rotation_degrees += giro
		global_position = newBack + (global_position - backWheel.global_position)
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		
		# Le damos un respiro a la IA después de girar (Ajustado dinámicamente a la velocidad)
		if es_ia:
			cooldown_ia = (float(TILE_SIZE) / SPEED) * 0.8
			
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
	moto_destruida.emit(es_ia, color_moto)
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
				
# --- FUNCIONES DE INTELIGENCIA ARTIFICIAL (NIVEL DIOS - ÁREA VORONOI) ---

func _pensar_ia() -> int:
	if not tile_map: return 0
	
	var direccion_actual = Vector2.UP.rotated(rotation).round()
	var pos_inicio = frontWheel.global_position
	
	# AUMENTADO: A esa velocidad (2000), necesita al menos 3 o 4 celdas de anticipación para no estamparse
	var peligro_inminente = _medir_distancia_libre(pos_inicio, direccion_actual, 4) < 3.5
	
	if peligro_inminente:
		var dir_izq = direccion_actual.rotated(deg_to_rad(-90)).round()
		var dir_der = direccion_actual.rotated(deg_to_rad(90)).round()
		
		# ¡MAGIA!: En lugar de medir líneas rectas, medimos toda el ÁREA disponible (hasta 150 celdas)
		var area_frente = _medir_area_disponible(pos_inicio, direccion_actual)
		var area_izq = _medir_area_disponible(pos_inicio, dir_izq)
		var area_der = _medir_area_disponible(pos_inicio, dir_der)
		
		# Buscamos la dirección que nos dé la mayor cantidad de celdas para sobrevivir
		var mayor_area = max(area_frente, max(area_izq, area_der))
		
		if mayor_area == area_izq:
			return -90
		elif mayor_area == area_der:
			return 90
		else:
			return 0 # Si el frente sigue siendo el mejor (raro si hay peligro, pero posible)
			
	# MODO CAZA AGRESIVO (Solo en difícil)
	elif dificultad_ia == "dificil" and randf() < 0.1: # 10% de probabilidad de buscar caza
		var presa = _buscar_presa()
		if presa:
			var dir_hacia_presa = (presa.global_position - pos_inicio).normalized()
			var dir_izq = direccion_actual.rotated(deg_to_rad(-90)).round()
			var dir_der = direccion_actual.rotated(deg_to_rad(90)).round()
			
			var dot_izq = dir_izq.dot(dir_hacia_presa)
			var dot_der = dir_der.dot(dir_hacia_presa)
			
			# Antes de atacar, se asegura de que el área hacia la que va a girar tenga al menos 40 celdas libres
			if dot_izq > 0.5 and _medir_area_disponible(pos_inicio, dir_izq, 40) >= 40:
				return -90
			elif dot_der > 0.5 and _medir_area_disponible(pos_inicio, dir_der, 40) >= 40:
				return 90

	return 0

# --- EL ALGORITMO FLOOD FILL ---
func _medir_area_disponible(pos_inicio: Vector2, direccion: Vector2, limite_busqueda: int = 150) -> int:
	var pos_local = tile_map.to_local(pos_inicio + (direccion * TILE_SIZE))
	var celda_inicial = tile_map.local_to_map(pos_local)
	
	if _es_celda_ocupada(celda_inicial):
		return 0 # Si el primer paso ya es muro, el área es 0
		
	# Colas para el algoritmo BFS (Búsqueda a lo ancho)
	var celdas_por_visitar = [celda_inicial]
	var celdas_visitadas = {celda_inicial: true}
	var area = 0
	
	var direcciones_vecinas = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	
	# Mientras haya celdas por explorar y no superemos el límite (para no congelar el juego)
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
	# 1. Revisa las estelas
	if tile_map.get_cell_source_id(celda) != -1: return true
	# 2. Revisa los bordes del mapa
	if border_map.get_cell_source_id(celda) != -1: return true
	
	# 3. Revisa otras motos (para que no se choque con los cuerpos antes de que pinten)
	var posicion_global_celda = tile_map.to_global(tile_map.map_to_local(celda))
	var parent = get_parent()
	if parent:
		for otra_moto in parent.get_children():
			if otra_moto != self and otra_moto.get("esta_viva"):
				if posicion_global_celda.distance_to(otra_moto.global_position) < TILE_SIZE:
					return true
					
	return false

func _medir_distancia_libre(origen: Vector2, direccion: Vector2, max_distancia_tiles: int) -> float:
	var max_distancia_px = max_distancia_tiles * TILE_SIZE
	var space_state = get_world_2d().direct_space_state
	var offset_lateral = direccion.rotated(PI/2) * (TILE_SIZE * 0.4) 
	
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
