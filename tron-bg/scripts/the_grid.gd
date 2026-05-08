extends Node2D

@export var lightcycles: Node2D
@export var escena_moto: PackedScene
@export var lines: TileMapLayer
@export var borders: TileMapLayer

@export var centro_mapa: Vector2 = Vector2(0, 0) 
@export var distancia_spawn: float = 4860.0 

const TILE_SIZE: int = 54

func _ready() -> void:
	var lista_colores = GameSettings.get_lista_completa_colores()
	iniciar_partida(lista_colores)

func iniciar_partida(colores: Array[String]):
	var total_motos = colores.size()
	
	for hijo in lightcycles.get_children():
		hijo.queue_free()
		
	for i in range(total_motos):
		var nueva_moto = escena_moto.instantiate()
		nueva_moto.color_moto = colores[i]
		nueva_moto.tile_map = lines
		nueva_moto.border_map = borders
		
		# Determinamos si es IA o Jugador Real
		if i >= GameSettings.num_jugadores_reales:
			nueva_moto.es_ia = true
			nueva_moto.dificultad_ia = GameSettings.dificultad_ia
		else:
			nueva_moto.es_ia = false
			# --- CAMBIO: Pedimos los controles a GameSettings ---
			var controles = GameSettings.get_controles(i)
			nueva_moto.input_left = controles["left"]
			nueva_moto.input_right = controles["right"]
			
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
