extends Control

export(String) var scene_path = ''

func _ready() -> void:
	$Bg/opciones/VBoxContainer/Play.connect("pressed",self, "_on_Play_pressed")
	$Bg/opciones/VBoxContainer/Options.connect("pressed", self, "_on_Options_pressed")
	$Bg/opciones/VBoxContainer/Quit.connect("pressed", self, "_on_Quit_pressed")
	
	# Asegurarnos de que el audio esté correctamente inicializado
	if has_node("/root/AudioManager"):
		# Inicializar buses y cargar configuración con valores por defecto a 100%
		get_node("/root/AudioManager").initialize_audio_buses()
		get_node("/root/AudioManager").load_audio_settings()
		get_node("/root/AudioManager").unmute_all_buses()
		print("MainMenu: Audio inicializado correctamente")


func _on_Play_pressed() -> void:
	LevelManager.goto_scene('res://scenes/%s.tscn' % [scene_path])

func _on_Options_pressed() -> void:
	# Creamos una instancia del menú de opciones
	var options_menu = load("res://interfaces/menu/Options.tscn").instance()
	# Indicamos que venimos del menú principal
	options_menu.previous_menu = "MainMenu"
	# Lo añadimos como hijo de este nodo (el menú principal)
	add_child(options_menu)
	# Ocultamos el menú principal mientras se muestra el de opciones
	$Bg.visible = false

func _on_Quit_pressed() -> void:
	get_tree().quit()
