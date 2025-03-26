extends Control

func _ready() -> void:
	$Bg/Background/VBoxContainer/Resume.connect('pressed', self, '_on_Resume_pressed')
	$Bg/Background/VBoxContainer/Options.connect("pressed", self, "_on_Options_pressed")
	$Bg/Background/VBoxContainer/Quit.connect('pressed', self, '_on_Quit_pressed')
	# Ocultar el menú al inicio
	visible = false
	# Asegurarnos de que el procesamiento de entrada esté activo
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Solo procesamos la tecla de pausa (ESC)
	if event.is_action_pressed('pause'):
		# Alternar el estado de pausa y visibilidad
		var new_pause_state = !get_tree().paused
		get_tree().paused = new_pause_state
		visible = new_pause_state
		
		# Si mostramos el menú, dar foco al botón de reanudar
		if visible:
			get_node('Bg/Background/VBoxContainer/Resume').grab_focus()

func _on_Resume_pressed() -> void:
	# Reanudar el juego
	get_tree().paused = false
	visible = false

func _on_Options_pressed() -> void:
	# Ocultar el menú de pausa
	visible = false
	
	# Desactivar el procesamiento de entrada para evitar que este menú
	# procese la tecla ESC mientras el menú de opciones esté abierto
	set_process_input(false)
	
	# Cargar y mostrar el menú de opciones
	var options_menu = load("res://interfaces/menu/Options.tscn").instance()
	options_menu.previous_menu = "Pause"
	get_parent().add_child(options_menu)
	
	# Conectar la señal para saber cuándo se cierra el menú de opciones
	options_menu.connect("tree_exited", self, "_on_options_closed")

func _on_options_closed() -> void:
	# Cuando se cierra el menú de opciones, reactivar el procesamiento de entrada
	# para que el menú de pausa pueda responder a la tecla ESC de nuevo
	set_process_input(true)


func _on_Quit_pressed() -> void:
	get_tree().quit()
