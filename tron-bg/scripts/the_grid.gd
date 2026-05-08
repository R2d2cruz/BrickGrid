extends Node2D

@export var lightcycles: Node2D
@export var escena_moto: PackedScene
@export var lines: TileMapLayer
@export var borders: TileMapLayer

@export var centro_mapa: Vector2 = Vector2(0, 0) 
@export var distancia_spawn: float = 4860.0 

const TILE_SIZE: int = 54

var motos_vivas: int = 0
var jugadores_vivos: int = 0

func _ready() -> void:
	Engine.time_scale = 1.0
	var lista_colores = GameSettings.get_lista_completa_colores()
	iniciar_partida(lista_colores)

func iniciar_partida(colores: Array[String]):
	var total_motos = colores.size()
	motos_vivas = total_motos
	jugadores_vivos = GameSettings.num_jugadores_reales
	
	for hijo in lightcycles.get_children():
		hijo.queue_free()
		
	for i in range(total_motos):
		var nueva_moto = escena_moto.instantiate()
		nueva_moto.color_moto = colores[i]
		nueva_moto.tile_map = lines
		nueva_moto.border_map = borders
		
		# --- CONECTAMOS LA SEÑAL DE DESTRUCCIÓN ---
		nueva_moto.moto_destruida.connect(_on_moto_destruida)
		
		if i >= GameSettings.num_jugadores_reales:
			nueva_moto.es_ia = true
			nueva_moto.dificultad_ia = GameSettings.dificultad_ia
		else:
			nueva_moto.es_ia = false
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

# --- NUEVA LÓGICA DE SUPERVIVENCIA ---
func _on_moto_destruida(es_ia_destruida: bool, color_destruido: String):
	motos_vivas -= 1
	if not es_ia_destruida:
		jugadores_vivos -= 1
		
	# 1. Si no quedan jugadores reales pero hay IAs compitiendo, aceleramos x4
	if jugadores_vivos <= 0 and motos_vivas >= 2:
		Engine.time_scale = 4.0
		
	# 2. Si queda 1 o 0 motos, termina la ronda
	if motos_vivas <= 1:
		Engine.time_scale = 1.0 # Devolvemos a la normalidad por si estaba en x4
		
		var ganador = "EMPATE"
		if motos_vivas == 1:
			# Buscamos a la única moto viva
			for moto in lightcycles.get_children():
				if moto.esta_viva:
					ganador = moto.color_moto
					break
					
		GameSettings.ultimo_ganador = ganador
		GameSettings.partida_jugada = true
		GameSettings.reset() # Limpiamos los colores elegidos para la próxima ronda
		
		_terminar_partida()

func _terminar_partida():
	# Esperamos 2 segundos para que el jugador vea la explosión final
	await get_tree().create_timer(2.0).timeout 
	
	# Cambiamos a la nueva escena de victoria (Asegúrate de poner tu ruta correcta)
	get_tree().change_scene_to_file("res://scenes/UI/victoria_terminal.tscn")
