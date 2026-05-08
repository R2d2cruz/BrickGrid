extends Control

enum MenuState { INPUT_NOMBRE, JUGAR, NUM_JUGADORES, NUM_IA, DIFICULTAD, COLOR_JUGADOR, INICIAR }

@onready var pantalla_texto: RichTextLabel = $PantallaTexto
@onready var timer_letras: Timer = $TimerLetras

# --- VARIABLES DEL MENÚ ---
var estado_actual: MenuState = MenuState.INPUT_NOMBRE
var escribiendo: bool = false
var texto_base: String = ""
var opciones_actuales: Array = []
var indice_seleccion: int = 0
var nombre_tipeado: String = "" # Aquí guardamos lo que el usuario escribe

func _ready() -> void:
	timer_letras.timeout.connect(_on_letra_escrita)
	
	if GameSettings.partida_jugada:
		_preparar_estado(MenuState.JUGAR)
	else:
		_preparar_estado(MenuState.INPUT_NOMBRE)

func _input(event: InputEvent) -> void:
	if escribiendo: return 
	
	# --- LÓGICA ESPECIAL PARA EL NOMBRE (CAPTURA DIRECTA) ---
	if estado_actual == MenuState.INPUT_NOMBRE:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_BACKSPACE:
				nombre_tipeado = nombre_tipeado.left(nombre_tipeado.length() - 1)
				_actualizar_pantalla()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				if nombre_tipeado.strip_edges() != "":
					GameSettings.nombre_jugador = nombre_tipeado
					_preparar_estado(MenuState.JUGAR)
			else:
				# Capturamos solo caracteres visibles
				var c = char(event.unicode)
				if c.is_empty() == false and nombre_tipeado.length() < 15:
					nombre_tipeado += c.to_upper()
					_actualizar_pantalla()
		return

	# --- LÓGICA DE NAVEGACIÓN ---
	if event.is_action_pressed("ui_down"):
		indice_seleccion = (indice_seleccion + 1) % opciones_actuales.size()
		_actualizar_pantalla()
	elif event.is_action_pressed("ui_up"):
		indice_seleccion = (indice_seleccion - 1 + opciones_actuales.size()) % opciones_actuales.size()
		_actualizar_pantalla()
	elif event.is_action_pressed("ui_accept"):
		_procesar_seleccion()

func _preparar_estado(nuevo_estado: MenuState) -> void:
	estado_actual = nuevo_estado
	opciones_actuales.clear()
	indice_seleccion = 0
	
	match estado_actual:
		MenuState.INPUT_NOMBRE:
			texto_base = "C:\\TRON_SYS> INSERTE NOMBRE DE USUARIO:\n"
		MenuState.JUGAR:
			if GameSettings.partida_jugada:
				# Texto para cuando vuelve a jugar (Sin Bienvenido)
				texto_base = "C:\\TRON_SYS> INICIAR NUEVA SECUENCIA DE JUEGO?\n"
			else:
				# Texto para la primera vez
				texto_base = "BIENVENIDO " + GameSettings.nombre_jugador + "\nQUIERES JUGAR UN JUEGO?\n"
			opciones_actuales = ["SI", "NO"]
		MenuState.NUM_JUGADORES:
			texto_base = "CUANTOS USUARIOS HABRA EN LA RED?\n"
			opciones_actuales = ["1", "2", "4"]
		MenuState.NUM_IA:
			texto_base = "CUANTOS PROGRAMAS COMPETIRAN?\n"
			var jugadores = GameSettings.num_jugadores_reales
			opciones_actuales = ["1", "3"] if jugadores == 1 else ["2"]
		MenuState.DIFICULTAD:
			texto_base = "DIFICULTAD DE LOS PROGRAMAS?\n"
			opciones_actuales = ["FACIL", "NORMAL", "DIFICIL"]
		MenuState.COLOR_JUGADOR:
			var n = GameSettings.nombre_jugador if GameSettings.colores_elegidos.size() == 0 else "JUGADOR " + str(GameSettings.colores_elegidos.size() + 1)
			texto_base = "COLOR DE MOTO PARA " + n + "?\n"
			opciones_actuales = GameSettings.get_colores_disponibles()
	
	_escribir_texto()

func _procesar_seleccion() -> void:
	var sel = opciones_actuales[indice_seleccion]
	
	match estado_actual:
		MenuState.JUGAR:
			if sel == "NO": get_tree().quit()
			else: _preparar_estado(MenuState.NUM_JUGADORES)
		MenuState.NUM_JUGADORES:
			GameSettings.num_jugadores_reales = sel.to_int()
			if GameSettings.num_jugadores_reales == 4: _preparar_estado(MenuState.COLOR_JUGADOR)
			else: _preparar_estado(MenuState.NUM_IA)
		MenuState.NUM_IA:
			GameSettings.num_programas_ia = sel.to_int()
			if GameSettings.num_programas_ia > 0: _preparar_estado(MenuState.DIFICULTAD)
			else: _preparar_estado(MenuState.COLOR_JUGADOR)
		MenuState.DIFICULTAD:
			GameSettings.dificultad_ia = sel.to_lower()
			_preparar_estado(MenuState.COLOR_JUGADOR)
		MenuState.COLOR_JUGADOR:
			GameSettings.registrar_color(sel)
			if GameSettings.colores_elegidos.size() < GameSettings.num_jugadores_reales:
				_preparar_estado(MenuState.COLOR_JUGADOR)
			else:
				# Aquí cambiamos a la escena del juego
				get_tree().change_scene_to_file("res://scenes/the_grid.tscn")

func _actualizar_pantalla() -> void:
	var t = texto_base + "\n"
	if estado_actual == MenuState.INPUT_NOMBRE:
		t += "> " + nombre_tipeado + "_" # El _ simula el cursor
	else:
		for i in range(opciones_actuales.size()):
			if i == indice_seleccion:
				t += "  " + opciones_actuales[i] + " <\n" # Indicador al final
			else:
				t += "  " + opciones_actuales[i] + "\n"
				
	pantalla_texto.text = t
	
	if not escribiendo:
		pantalla_texto.visible_characters = -1

func _escribir_texto() -> void:
	escribiendo = true
	pantalla_texto.visible_characters = 0
	_actualizar_pantalla()
	timer_letras.start()

func _on_letra_escrita() -> void:
	pantalla_texto.visible_characters += 1
	if pantalla_texto.visible_characters >= pantalla_texto.text.length():
		timer_letras.stop()
		escribiendo = false
