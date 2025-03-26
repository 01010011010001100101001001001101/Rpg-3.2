extends Control

onready var audio_panel = $Bg/AudioPanel
onready var controls_panel = $Bg/ControlsPanel
onready var music_slider = $Bg/AudioPanel/MusicSlider
onready var ambient_slider = $Bg/AudioPanel/AmbientSlider
onready var music_value_label = $Bg/AudioPanel/MusicValueLabel
onready var ambient_value_label = $Bg/AudioPanel/AmbientValueLabel
onready var move_left_input = $Bg/ControlsPanel/MoveLeftInput
onready var move_right_input = $Bg/ControlsPanel/MoveRightInput
onready var jump_input = $Bg/ControlsPanel/JumpInput
onready var attack_input = $Bg/ControlsPanel/AttackInput
onready var waiting_for_input = false
onready var action_to_remap = ""
var previous_menu = ""

const CONFIG_FILE = "user://settings.cfg"
var config = ConfigFile.new()

func _ready():
	# Asegurar que estamos en la capa de pausa para que no se congele el juego
	if previous_menu == "Pause":
		pause_mode = PAUSE_MODE_PROCESS
	
	# Establecer valores por defecto (100%)
	music_slider.min_value = 0
	music_slider.max_value = 100
	ambient_slider.min_value = 0
	ambient_slider.max_value = 100
	music_slider.value = 100
	ambient_slider.value = 100
	music_value_label.text = "100%"
	ambient_value_label.text = "100%"
	
	# Cargar configuraciones guardadas (si existen)
	load_settings()
	hide_panels()
	connect_signals()
	make_inputs_non_editable()
	connect_input_fields()
	
	# Comprobar si AudioManager existe antes de usarlo
	if has_node("/root/AudioManager"):
		# Forzar inicialización y mostrar estado de audio para depuración
		get_node("/root/AudioManager").force_initialize_buses()
		get_node("/root/AudioManager").force_audio_settings()
	else:
		print("AudioManager no encontrado - se usará control de audio directo")
		# Intentar configurar directamente los buses
		initialize_audio_buses_direct()
	
	# Asegurarse de que el botón Audio tenga el foco al inicio
	$Bg/Audio.grab_focus()
	
	# Actualizar valores de sliders desde la configuración actual
	sync_sliders_with_audio_settings()
	
	# Simular cambio en los sliders para actualizar los valores inmediatamente
	_on_music_value_changed(music_slider.value)
	_on_ambient_value_changed(ambient_slider.value)

func hide_panels():
	audio_panel.hide()
	controls_panel.hide()

func connect_signals():
	# Conexión de botones
	$Bg/Audio.connect("pressed", self, "_on_AudioButton_pressed")
	$Bg/Controles.connect("pressed", self, "_on_ControlsButton_pressed")
	$Bg/Volver.connect("pressed", self, "_on_BackButton_pressed")
	
	# Conexión de sliders - comprobamos si ya están conectados para evitar duplicados
	if !music_slider.is_connected("value_changed", self, "_on_music_value_changed"):
		music_slider.connect("value_changed", self, "_on_music_value_changed")
	
	if !ambient_slider.is_connected("value_changed", self, "_on_ambient_value_changed"):
		ambient_slider.connect("value_changed", self, "_on_ambient_value_changed")
	
	# Conexión de botón de reset
	$Bg/ControlsPanel/ResetButton.connect("pressed", self, "_on_reset_controls_pressed")

func make_inputs_non_editable():
	move_left_input.editable = false
	move_right_input.editable = false
	jump_input.editable = false
	attack_input.editable = false

func connect_input_fields():
	move_left_input.connect("focus_entered", self, "_on_input_field_focus_entered", ["move_left"])
	move_right_input.connect("focus_entered", self, "_on_input_field_focus_entered", ["move_right"])
	jump_input.connect("focus_entered", self, "_on_input_field_focus_entered", ["jump"])
	attack_input.connect("focus_entered", self, "_on_input_field_focus_entered", ["attack"])

func _on_AudioButton_pressed():
	controls_panel.hide()
	audio_panel.show()

	# Asegurarse de que el primer slider tenga el foco
	music_slider.grab_focus()

func _on_ControlsButton_pressed():
	audio_panel.hide()
	controls_panel.show()

	# Asegurarse de que el primer campo de entrada tenga el foco
	move_left_input.grab_focus()

func _on_BackButton_pressed():
	# Forzar la aplicación inmediata de la configuración de audio en todo el juego
	if has_node("/root/AudioManager"):
		print("Aplicando cambios de audio inmediatamente antes de volver")
		var audio_manager = get_node("/root/AudioManager")
		
		# Aplicar valores actuales con fuerza
		audio_manager.force_audio_settings()
		
		# Escanear todos los nodos existentes para aplicar configuración
		audio_manager.call_deferred("scan_existing_players")
	
	# Si venimos del menú de pausa, volvemos a él
	if previous_menu == "Pause":
		# Buscamos el menú de pausa actual en el árbol
		var pause_menu = get_tree().get_root().find_node("Pause", true, false)
		
		# Si lo encontramos, lo mostramos y le damos el foco
		if pause_menu:
			pause_menu.visible = true
			pause_menu.get_node('Bg/Background/VBoxContainer/Resume').grab_focus()
			
		# Mantenemos el estado de pausa activo ya que estamos volviendo al menú de pausa
		get_tree().paused = true
	else:
		# Si venimos del menú principal, volvemos a él
		get_tree().change_scene("res://interfaces/menu/MainMenu.tscn")
	
	# Eliminamos el menú de opciones
	queue_free()

# Manejar la tecla ESC para volver al menú anterior
func _input(event):
	# Si estamos esperando input para remapear controles, usamos la lógica existente
	if waiting_for_input:
		# IMPORTANTE: Consumir TODOS los eventos de teclado y ratón mientras esperamos input
		# Esto evita que las teclas de navegación (arriba, abajo) muevan el foco a otros campos
		if event is InputEventKey or event is InputEventMouseButton:
			# Si se hace clic derecho mientras esperamos input, desasignamos la tecla
			if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
				print("Desasignando tecla para la acción: " + action_to_remap)
				# Borrar todos los eventos para esta acción
				InputMap.action_erase_events(action_to_remap)
				
				# Añadir un evento nulo para que el juego no se rompa si se necesita esta acción
				# Esto evita errores si el juego intenta usar una acción sin eventos asignados
				var dummy_event = InputEventKey.new()
				dummy_event.scancode = 0  # Código 0 no corresponde a ninguna tecla real
				InputMap.action_add_event(action_to_remap, dummy_event)
				
				# Actualizar el texto del campo
				match action_to_remap:
					"move_left":
						move_left_input.text = "Sin asignar"
					"move_right":
						move_right_input.text = "Sin asignar"
					"jump":
						jump_input.text = "Sin asignar"
					"attack":
						attack_input.text = "Sin asignar"
				
				# Guardar configuraciones y salir del modo de espera
				waiting_for_input = false
				save_settings()
				get_tree().set_input_as_handled()
				return
			
			# Ignorar clicks del ratón izquierdo para evitar asignaciones accidentales
			if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
				get_tree().set_input_as_handled()
				return
			
			# Si se presionó ESC mientras esperamos input, cancelamos la asignación
			if event is InputEventKey and event.scancode == KEY_ESCAPE:
				print("Cancelando asignación de tecla")
				waiting_for_input = false
				update_button_labels() # Restaurar las etiquetas originales
				get_tree().set_input_as_handled()
				return
			
			# Si es un evento de tecla válido y está siendo presionado (no liberado)
			if event is InputEventKey and event.pressed:
				print("Procesando tecla: " + OS.get_scancode_string(event.scancode))
				
				# Verificar que no esté ya asignada a otra acción
				if not is_event_already_assigned(event):
					# Borrar eventos existentes para esta acción
					InputMap.action_erase_events(action_to_remap)
					
					# Añadir el nuevo evento
					InputMap.action_add_event(action_to_remap, event)
					print("Asignada tecla: " + OS.get_scancode_string(event.scancode) + " a la acción: " + action_to_remap)
					
					# Finalizar espera y actualizar
					waiting_for_input = false
					save_settings()
					update_button_labels()
				elif event is InputEventKey and event.pressed:
					print("La tecla ya está asignada a otra acción")
			
			# IMPORTANTE: Consumir TODOS los eventos mientras esperamos input
			# para evitar navegación de UI con las teclas de dirección
			get_tree().set_input_as_handled()
			return
	
	# Si no estamos remapeando, verificamos si se presionó ESC para volver
	elif event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		_on_BackButton_pressed()
		# Consumimos el evento para que no lo procese el menú de pausa
		get_tree().set_input_as_handled()

func _on_input_field_focus_entered(action):
	# Activar modo de espera para input
	waiting_for_input = true
	action_to_remap = action
	
	# Cambiar el texto del campo para indicar que está esperando input
	match action:
		"move_left":
			move_left_input.text = "Presiona una tecla..."
		"move_right":
			move_right_input.text = "Presiona una tecla..."
		"jump":
			jump_input.text = "Presiona una tecla..."
		"attack":
			attack_input.text = "Presiona una tecla..."
	
	print("Esperando input para la acción: " + action)

func is_event_already_assigned(event):
	for action in ["move_left", "move_right", "jump", "attack"]:
		var events = InputMap.get_action_list(action)
		for e in events:
			if e.as_text() == event.as_text():
				return true
	return false

func _on_reset_controls_pressed():
	reset_default_controls()
	update_button_labels()
	save_settings()

func reset_default_controls():
	# Reset move_left
	InputMap.action_erase_events("move_left")
	var ev = InputEventKey.new()
	ev.scancode = KEY_A
	InputMap.action_add_event("move_left", ev)
	ev = InputEventKey.new()
	ev.scancode = KEY_LEFT
	InputMap.action_add_event("move_left", ev)
	
	# Reset move_right
	InputMap.action_erase_events("move_right")
	ev = InputEventKey.new()
	ev.scancode = KEY_D
	InputMap.action_add_event("move_right", ev)
	ev = InputEventKey.new()
	ev.scancode = KEY_RIGHT
	InputMap.action_add_event("move_right", ev)
	
	# Reset jump
	InputMap.action_erase_events("jump")
	ev = InputEventKey.new()
	ev.scancode = KEY_SPACE
	InputMap.action_add_event("jump", ev)
	
	# Reset attack
	InputMap.action_erase_events("attack")
	ev = InputEventKey.new()
	ev.scancode = KEY_F
	InputMap.action_add_event("attack", ev)
	var mouse_ev = InputEventMouseButton.new()
	mouse_ev.button_index = BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_ev)

func update_button_labels():
	for action in ["move_left", "move_right", "jump", "attack"]:
		var events = InputMap.get_action_list(action)
		if events.size() > 0:
			var input_field
			match action:
				"move_left":
					input_field = move_left_input
				"move_right":
					input_field = move_right_input
				"jump":
					input_field = jump_input
				"attack":
					input_field = attack_input
			
			if input_field:
				input_field.text = events[0].as_text()

func save_settings():
	# Guardamos los valores de audio como porcentajes (0-100)
	config.set_value("audio", "sfx", music_slider.value)  # Efectos de sonido de los personajes
	config.set_value("audio", "music", ambient_slider.value)  # Música de niveles
	
	# Guardamos los controles
	for action in ["move_left", "move_right", "jump", "attack"]:
		var events = InputMap.get_action_list(action)
		if events.size() > 0:
			config.set_value("controls", action, events[0])
	
	config.save(CONFIG_FILE)

func load_settings():
	var err = config.load(CONFIG_FILE)
	if err != OK:
		# Si no hay configuración guardada, establecemos valores predeterminados
		print("No config file found, setting default audio values")
		music_slider.value = 100
		ambient_slider.value = 100
		music_value_label.text = "100%"
		ambient_value_label.text = "100%"
		
		# Aplicar valores por defecto a los buses de audio
		var sfx_bus_idx = AudioServer.get_bus_index("SFX")
		if sfx_bus_idx != -1:
			AudioServer.set_bus_volume_db(sfx_bus_idx, linear2db(1.0))  # 100%
		
		var music_bus_idx = AudioServer.get_bus_index("Music")
		if music_bus_idx != -1:
			AudioServer.set_bus_volume_db(music_bus_idx, linear2db(1.0))  # 100%
		
		var ambient_bus_idx = AudioServer.get_bus_index("Ambient")
		if ambient_bus_idx != -1:
			AudioServer.set_bus_volume_db(ambient_bus_idx, linear2db(1.0))  # 100%
		
		return
	
	# Cargamos los valores de audio
	var sfx_value = config.get_value("audio", "sfx", 100)  # Efectos de sonido de los personajes
	var music_value = config.get_value("audio", "music", 100)  # Música de niveles
	
	print("Loaded audio settings - SFX: " + str(sfx_value) + "%, Music: " + str(music_value) + "%")
	
	# Aplicamos los valores a los sliders
	music_slider.value = sfx_value
	ambient_slider.value = music_value
	
	# Actualizamos las etiquetas
	music_value_label.text = str(int(sfx_value)) + "%"
	ambient_value_label.text = str(int(music_value)) + "%"
	
	# Aplicamos los valores a los buses de audio
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx != -1:
		# Si el valor es 0, silenciamos el bus completamente
		if sfx_value == 0:
			AudioServer.set_bus_mute(sfx_bus_idx, true)
		else:
			# Desactivamos el mute si estaba activado
			AudioServer.set_bus_mute(sfx_bus_idx, false)
			AudioServer.set_bus_volume_db(sfx_bus_idx, linear2db(sfx_value / 100))
	
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		# Si el valor es 0, silenciamos el bus completamente
		if music_value == 0:
			AudioServer.set_bus_mute(music_bus_idx, true)
		else:
			# Desactivamos el mute si estaba activado
			AudioServer.set_bus_mute(music_bus_idx, false)
			AudioServer.set_bus_volume_db(music_bus_idx, linear2db(music_value / 100))
	
	# También aplicamos el mismo valor al bus Ambient para mantener compatibilidad
	var ambient_bus_idx = AudioServer.get_bus_index("Ambient")
	if ambient_bus_idx != -1:
		# Si el valor es 0, silenciamos el bus completamente
		if music_value == 0:
			AudioServer.set_bus_mute(ambient_bus_idx, true)
		else:
			AudioServer.set_bus_mute(ambient_bus_idx, false)
			AudioServer.set_bus_volume_db(ambient_bus_idx, linear2db(music_value / 100))
	
	# Cargamos las configuraciones de controles
	for action in ["move_left", "move_right", "jump", "attack"]:
		var event = config.get_value("controls", action, null)
		if event != null:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
	
	# Actualizamos las etiquetas de los controles
	update_button_labels()

func initialize_audio_buses_direct():
	# Configuración directa de buses de audio si no hay AudioManager
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx != -1:
		AudioServer.set_bus_volume_db(sfx_bus_idx, linear2db(1.0))  # 100%
	
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		AudioServer.set_bus_volume_db(music_bus_idx, linear2db(1.0))  # 100%
	
	var ambient_bus_idx = AudioServer.get_bus_index("Ambient")
	if ambient_bus_idx != -1:
		AudioServer.set_bus_volume_db(ambient_bus_idx, linear2db(1.0))  # 100%

func sync_sliders_with_audio_settings():
	# Esta función actualiza los sliders según los valores actuales de los buses de audio
	# Asegurando que reflejen correctamente el estado actual del sistema de audio
	
	# Si AudioManager está disponible, usarlo para obtener los valores actuales
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		
		# Usar los valores almacenados en AudioManager
		music_slider.value = audio_manager.current_sfx_volume
		ambient_slider.value = audio_manager.current_music_volume
		
		# Actualizar las etiquetas
		music_value_label.text = str(int(audio_manager.current_sfx_volume)) + "%"
		ambient_value_label.text = str(int(audio_manager.current_music_volume)) + "%"
		
		print("Sliders sincronizados con AudioManager: SFX=" + str(audio_manager.current_sfx_volume) + 
			", Music=" + str(audio_manager.current_music_volume))
	else:
		# Obtener valores directamente de los buses de audio
		var sfx_bus_idx = AudioServer.get_bus_index("SFX")
		var music_bus_idx = AudioServer.get_bus_index("Music")
		
		if sfx_bus_idx != -1 and not AudioServer.is_bus_mute(sfx_bus_idx):
			var sfx_db = AudioServer.get_bus_volume_db(sfx_bus_idx)
			var sfx_percent = int(db2linear(sfx_db) * 100)
			music_slider.value = sfx_percent
			music_value_label.text = str(sfx_percent) + "%"
		else:
			# Si está silenciado, establecer a 0
			music_slider.value = 0
			music_value_label.text = "0%"
		
		if music_bus_idx != -1 and not AudioServer.is_bus_mute(music_bus_idx):
			var music_db = AudioServer.get_bus_volume_db(music_bus_idx)
			var music_percent = int(db2linear(music_db) * 100)
			ambient_slider.value = music_percent
			ambient_value_label.text = str(music_percent) + "%"
		else:
			# Si está silenciado, establecer a 0
			ambient_slider.value = 0
			ambient_value_label.text = "0%"

func _on_music_value_changed(value):
	# El sonido de música representa los efectos de sonido de los personajes (SFX)
	# Comprobar si podemos usar AudioManager
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").update_bus_volume("SFX", value)
	else:
		# Aplicar directamente al bus de audio
		var bus_index = AudioServer.get_bus_index("SFX")
		if bus_index != -1:
			# Si el valor es 0, silenciamos el bus completamente
			if value == 0:
				AudioServer.set_bus_mute(bus_index, true)
			else:
				# Desactivamos el mute si estaba activado
				AudioServer.set_bus_mute(bus_index, false)
				# Convertimos el valor (0-100) a decibeles y lo aplicamos al bus
				AudioServer.set_bus_volume_db(bus_index, linear2db(value / 100))
	
	# Actualizar la etiqueta de porcentaje
	music_value_label.text = str(int(value)) + "%"
	
	# Guardamos la configuración
	save_settings()
	
	print("SFX Volume set to: " + str(value) + "%")

func _on_ambient_value_changed(value):
	# El sonido de ambiente representa la música del juego (Music)
	print("DEBUG: _on_ambient_value_changed llamado con valor: " + str(value))
	
	# Comprobar si podemos usar AudioManager
	if has_node("/root/AudioManager"):
		print("DEBUG: Usando AudioManager para controlar volumen de Music")
		# Es fundamental actualizar ambos buses: Music y Ambient
		var audio_manager = get_node("/root/AudioManager")
		
		# Guardamos el valor actual para usarlo en próximas comparaciones
		audio_manager.current_music_volume = value
		
		# Aplicamos el cambio al bus Music
		audio_manager.set_volume("Music", value)
		
		# También aplicamos el mismo valor al bus Ambient
		audio_manager.set_volume("Ambient", value)
		
		# Forzar silenciamiento directo en nodos con autoplay si el volumen es 0
		if value <= 0:
			# Buscar todos los AudioStreamPlayer y silenciar directamente los que tengan bus Music
			audio_manager.call_deferred("scan_existing_players")
	else:
		print("DEBUG: Control directo de buses para Music")
		# Verificar si el bus existe
		var music_bus_idx = AudioServer.get_bus_index("Music")
		if music_bus_idx == -1:
			print("ERROR: Bus Music no encontrado")
			return
			
		# Variable para almacenar el valor en decibeles
		var db_value = linear2db(value / 100)
		
		# Aplicar directamente al bus de audio Music
		if value <= 0:
			print("DEBUG: Silenciando Music completamente")
			AudioServer.set_bus_mute(music_bus_idx, true)
		else:
			# Desactivamos el mute si estaba activado
			AudioServer.set_bus_mute(music_bus_idx, false)
			# Aplicamos el valor en decibeles al bus
			print("DEBUG: Ajustando Music a " + str(value) + "% (" + str(db_value) + "dB)")
			AudioServer.set_bus_volume_db(music_bus_idx, db_value)
		
		# También aplicar al bus Ambient (para consistencia)
		var ambient_bus_idx = AudioServer.get_bus_index("Ambient")
		if ambient_bus_idx != -1:
			if value <= 0:
				AudioServer.set_bus_mute(ambient_bus_idx, true)
			else:
				AudioServer.set_bus_mute(ambient_bus_idx, false)
				AudioServer.set_bus_volume_db(ambient_bus_idx, db_value)
	
	# Actualizar la etiqueta de porcentaje
	ambient_value_label.text = str(int(value)) + "%"
	
	# Guardamos la configuración
	save_settings()
	
	print("Music/Ambient Volume set to: " + str(value) + "%")
