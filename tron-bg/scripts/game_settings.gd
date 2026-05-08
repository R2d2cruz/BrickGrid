extends Node

# Datos de la partida
var nombre_jugador: String = "USER"
var num_jugadores_reales: int = 1
var num_programas_ia: int = 0
var dificultad_ia: String = "normal"
var colores_elegidos: Array[String] = []

var ultimo_ganador: String = ""
var partida_jugada: bool = false

# Gestión de colores
var catalogo_colores: Dictionary = {
	"BLANCO": "white", "AZUL": "blue", "AMARILLO": "yellow", 
	"VERDE": "green", "NARANJA": "orange", "ROJO": "red"
}

var controles_jugadores: Array[Dictionary] = [
	{"left": "p1_left", "right": "p1_right"}, # Jugador 1 
	{"left": "p2_left", "right": "p2_right"}, # Jugador 2
	{"left": "p3_left", "right": "p3_right"}, # Jugador 3
	{"left": "p4_left", "right": "p4_right"}  # Jugador 4
]

func get_controles(indice_jugador: int) -> Dictionary:
	if indice_jugador < controles_jugadores.size():
		return controles_jugadores[indice_jugador]
	# Por seguridad, si hay un error, devolvemos un control vacío
	return {"left": "", "right": ""}

func reset():
	colores_elegidos.clear()

func get_colores_disponibles() -> Array:
	var disponibles = []
	for nombre in catalogo_colores.keys():
		if not catalogo_colores[nombre] in colores_elegidos:
			disponibles.append(nombre)
	return disponibles

func registrar_color(nombre_espanol: String):
	colores_elegidos.append(catalogo_colores[nombre_espanol])

func get_lista_completa_colores() -> Array[String]:
	# Combina colores de jugadores + colores para la IA (los que sobren)
	var lista = colores_elegidos.duplicate()
	var todos = catalogo_colores.values()
	
	for c in todos:
		if lista.size() < (num_jugadores_reales + num_programas_ia):
			if not c in lista:
				lista.append(c)
	return lista
