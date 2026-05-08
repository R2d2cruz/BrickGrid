extends Node2D

@export var lightcycles: Node2D
@export var escena_moto: PackedScene
@export var lines: TileMapLayer
@export var borders: TileMapLayer

@export var centro_mapa: Vector2 = Vector2(0, 0) 
@export var distancia_spawn: float = 4860.0 

const TILE_SIZE: int = 54

func _ready() -> void:
	iniciar_partida(["blue", "orange", "white", "green"])

func iniciar_partida(colores: Array[String]):
	var controles_jugadores = [
		{"left": "p1_left", "right": "p1_right"}, 
		{"left": "p2_left", "right": "p2_right"},
		{"left": "p3_left", "right": "p3_right"},
		{"left": "p4_left", "right": "p4_right"}  
	]

	# Configuramos P1 como jugador, y los demás como IA
	var is_ai_list = [false, true, true, true] 
	
	# Definimos la dificultad inicial para las IAs (luego el menú cambiará esto)
	var diff_list = ["", "facil", "normal", "dificil"]

	for hijo in lightcycles.get_children():
		hijo.queue_free()
		
	for i in range(colores.size()):
		var nueva_moto = escena_moto.instantiate()
		nueva_moto.color_moto = colores[i]
		
		# Asignamos AMBOS TileMaps
		nueva_moto.tile_map = lines
		nueva_moto.border_map = borders 
		
		if i < is_ai_list.size():
			nueva_moto.es_ia = is_ai_list[i]
			if nueva_moto.es_ia:
				nueva_moto.dificultad_ia = diff_list[i]
		
		if not nueva_moto.es_ia and i < controles_jugadores.size():
			nueva_moto.input_left = controles_jugadores[i]["left"]
			nueva_moto.input_right = controles_jugadores[i]["right"]
			
		lightcycles.add_child(nueva_moto)
		
	_organizar_motos()
	
	for moto in lightcycles.get_children():
		moto.configurar_inicio()


func _organizar_motos():
	var motos = lightcycles.get_children()
	var cantidad = motos.size()
	
	if cantidad == 2:
		_colocar_moto(motos[0], centro_mapa + Vector2(-distancia_spawn, 0), 90)
		_colocar_moto(motos[1], centro_mapa + Vector2(distancia_spawn, 0), -90)
		
	elif cantidad == 4:
		_colocar_moto(motos[0], centro_mapa + Vector2(-distancia_spawn, -distancia_spawn), 90)
		_colocar_moto(motos[1], centro_mapa + Vector2(distancia_spawn, -distancia_spawn), 180)
		_colocar_moto(motos[2], centro_mapa + Vector2(distancia_spawn, distancia_spawn), -90)
		_colocar_moto(motos[3], centro_mapa + Vector2(-distancia_spawn, distancia_spawn), 0)


func _colocar_moto(moto: CharacterBody2D, posicion_deseada: Vector2, rotacion_grados: float):
	moto.rotation_degrees = rotacion_grados
	moto.global_position = posicion_deseada.snapped(Vector2(TILE_SIZE, TILE_SIZE))
