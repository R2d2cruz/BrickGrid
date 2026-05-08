extends Control

@onready var pantalla_texto: RichTextLabel = $PantallaTexto
@onready var timer_letras: Timer = $TimerLetras

func _ready():
	timer_letras.timeout.connect(_on_letra_escrita)
	
	var texto_victoria = "C:\\TRON_SYS> FIN DE SECUENCIA.\n\n"
	
	if GameSettings.ultimo_ganador == "EMPATE":
		texto_victoria += "RESULTADO: MUTUA DESTRUCCIÓN (EMPATE).\n\n"
	else:
		texto_victoria += "PROGRAMA GANADOR: " + GameSettings.ultimo_ganador.to_upper() + "\n\n"
		
	texto_victoria += "RETORNANDO AL SISTEMA PRINCIPAL..."
	
	pantalla_texto.text = texto_victoria
	pantalla_texto.visible_characters = 0
	timer_letras.start()

func _on_letra_escrita():
	pantalla_texto.visible_characters += 1
	if pantalla_texto.visible_characters >= pantalla_texto.text.length():
		timer_letras.stop()
		_volver_al_menu()

func _volver_al_menu():
	# Le damos 3 segundos al jugador para que lea antes de volver al menú
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/UI/menu_terminal.tscn")
