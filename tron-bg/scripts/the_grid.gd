extends Node2D

@export var lightcycles: Node2D
@export var escena_moto: PackedScene
@export var lines: TileMapLayer

@export var centro_mapa: Vector2 = Vector2(0, 0) 
@export var distancia_spawn: float = 3240.0 

const TILE_SIZE: int = 54

func _ready() -> void:
	iniciar_partida(["blue", "orange", "white", "green"])

func iniciar_partida(colores: Array[String]):
	# Definimos los "nombres" de los inputs para cada jugador posible
	var controles_jugadores = [
		{"left": "p1_left", "right": "p1_right"}, # Jugador 1 (ej: A y D)
		{"left": "p2_left", "right": "p2_right"}, # Jugador 2 (ej: Flechas Izq y Der)
		{"left": "p3_left", "right": "p3_right"}, # Jugador 3 (ej: J y L)
		{"left": "p4_left", "right": "p4_right"}  # Jugador 4 (ej: Numpad 4 y 6)
	]

	for hijo in lightcycles.get_children():
		hijo.queue_free()
		
	# Usamos un bucle for tradicional para saber qué número de moto estamos creando
	for i in range(colores.size()):
		var nueva_moto = escena_moto.instantiate()
		nueva_moto.color_moto = colores[i]
		nueva_moto.tile_map = lines
		
		# Asignamos los controles dependiendo del jugador (P1, P2, etc.)
		if i < controles_jugadores.size():
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
