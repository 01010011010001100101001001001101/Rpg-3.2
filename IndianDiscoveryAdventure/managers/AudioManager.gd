extends Node

onready var SFXPlayer = $SFXPlayer
onready var MusicPlayer = $MusicPlayer
onready var AmbiancePlayer = $AmbiancePlayer

# Variables para almacenar los valores de volumen actuales
var current_sfx_volume = 100
var current_music_volume = 100

func _ready():
	# Inicializa los buses de audio al inicio
	initialize_audio_buses()
	# Carga los valores de configuración guardados
	load_audio_settings()
	# Asegurarse de que ningún bus esté silenciado al iniciar
	unmute_all_buses()
	# Forzar siempre valores de inicio al 100% si no hay configuración
	force_default_audio_values()
	print("AudioManager iniciado - todos los buses activos al 100%")
	
	# Conectar a la señal de cambio de escena para asignar buses automáticamente
	get_tree().connect("node_added", self, "_on_node_added")
	
	# Conectar a la señal de cambio de escena para buscar players existentes
	get_tree().connect("tree_changed", self, "_on_tree_changed")
	
	# Esperar un breve momento y luego forzar configuraciones de audio
	yield(get_tree().create_timer(0.5), "timeout")
	force_audio_settings()
	
	# Conectarse al sistema de pausas para asegurar que la música siga funcionando durante las pausas
	pause_mode = PAUSE_MODE_PROCESS

# Esta función se llama cuando la estructura del árbol de escena cambia
func _on_tree_changed():
	# Escanear toda la escena para encontrar y asignar buses a los AudioStreamPlayer existentes
	call_deferred("scan_existing_players")

# Escanea todos los AudioStreamPlayer existentes y les asigna el bus correcto
func scan_existing_players():
	# Obtenemos el nodo raíz
	var root = get_tree().get_root()
	# Buscamos todos los AudioStreamPlayer que ya existen en la escena
	scan_node_for_players(root)
	print("Escaneo de AudioStreamPlayer existentes completado")
	
	# Muy importante: aplica nuevamente la configuración de audio actual
	# para asegurarse de que los nuevos nodos respeten el volumen configurado
	apply_current_volume_settings()

# Función para aplicar los valores de volumen actuales a los buses de audio
func apply_current_volume_settings():
	# Aplicar configuración de volumen actual a los buses
	set_volume("SFX", current_sfx_volume)
	set_volume("Music", current_music_volume)
	set_volume("Ambient", current_music_volume)
	print("Aplicada configuración actual: SFX " + str(current_sfx_volume) + "%, Music " + str(current_music_volume) + "%")
	
	# Si el volumen de música es mayor que 0, reactivar reproductores silenciados
	if current_music_volume > 0:
		call_deferred("reactivate_muted_players")

# Función recursiva para buscar en todos los nodos de la escena
func scan_node_for_players(node):
	# Si el nodo es un AudioStreamPlayer, asignar el bus correcto
	if node is AudioStreamPlayer:
		assign_bus_to_player(node)
	
	# Revisar todos los nodos hijos
	for child in node.get_children():
		scan_node_for_players(child)

# Función para asignar el bus correcto a un AudioStreamPlayer
func assign_bus_to_player(node):
	# Verificar el nombre del nodo o del padre para decidir qué bus asignar
	var parent_name = ""
	if node.get_parent():
		parent_name = node.get_parent().name
	
	# Si el nodo o su padre se llama "Music" o "Ambiance", asignar al bus "Music"
	if node.name == "Music" or parent_name == "Ambiance" or parent_name == "Music":
		node.bus = "Music"
		print("Asignado bus Music a nodo existente " + node.name)
		
		# Importante: Si el volumen está a 0, asegurarse de que la música esté silenciada
		if current_music_volume <= 0:
			# Si el AudioStreamPlayer tiene autoplay activado, también silenciarlo directamente
			if node.autoplay:
				node.volume_db = -80 # Prácticamente silencio
				print("Silenciado autoplay de nodo " + node.name)
	
	# Si el nodo se llama "SFX" o contiene "sfx" en su nombre, asignar al bus "SFX"
	elif node.name == "SFX" or "sfx" in node.name.to_lower():
		node.bus = "SFX"
		print("Asignado bus SFX a nodo existente " + node.name)
		
		# También silenciar efectos si están a 0
		if current_sfx_volume <= 0:
			if node.autoplay:
				node.volume_db = -80 # Prácticamente silencio

# Inicializa los buses de audio si no existen
func initialize_audio_buses():
	# Inicializar bus de música
	if AudioServer.get_bus_index("Music") == -1:
		print("Creando bus Music")
		var music_bus_idx = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_send(music_bus_idx, "Master")
		AudioServer.set_bus_volume_db(music_bus_idx, linear2db(1.0)) # 100%
	
	# Inicializar bus de ambiente
	if AudioServer.get_bus_index("Ambient") == -1:
		print("Creando bus Ambient")
		var ambient_bus_idx = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(ambient_bus_idx, "Ambient")
		AudioServer.set_bus_send(ambient_bus_idx, "Master")
		AudioServer.set_bus_volume_db(ambient_bus_idx, linear2db(1.0)) # 100%
	
	# Inicializar bus de efectos
	if AudioServer.get_bus_index("SFX") == -1:
		print("Creando bus SFX")
		var sfx_bus_idx = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(sfx_bus_idx, "Master")
		AudioServer.set_bus_volume_db(sfx_bus_idx, linear2db(1.0)) # 100%

# Esta función se llama cada vez que se añade un nodo al árbol de escena
func _on_node_added(node):
	# Verificar si el nodo es un AudioStreamPlayer
	if node is AudioStreamPlayer:
		assign_bus_to_player(node)

# Desactivar mute en todos los buses
func unmute_all_buses():
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_mute(master_idx, false)
		AudioServer.set_bus_volume_db(master_idx, linear2db(1.0)) # 100%
		
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_mute(music_idx, false)
		AudioServer.set_bus_volume_db(music_idx, linear2db(1.0)) # 100%
		
	var ambient_idx = AudioServer.get_bus_index("Ambient")
	if ambient_idx != -1:
		AudioServer.set_bus_mute(ambient_idx, false)
		AudioServer.set_bus_volume_db(ambient_idx, linear2db(1.0)) # 100%
		
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_mute(sfx_idx, false)
		AudioServer.set_bus_volume_db(sfx_idx, linear2db(1.0)) # 100%

# Función para cargar la configuración de audio
func load_audio_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		# No hay configuración guardada, usamos valores predeterminados
		print("No audio settings found, using defaults")
		set_volume("SFX", 100)    # 100% para efectos de sonido
		set_volume("Music", 100)  # 100% para música
		set_volume("Ambient", 100) # 100% para sonidos ambientales
		current_sfx_volume = 100
		current_music_volume = 100
		return

	# Cargar configuraciones guardadas
	var sfx_value = config.get_value("audio", "sfx", 100)
	var music_value = config.get_value("audio", "music", 100)
	
	# Guardar en variables para uso futuro
	current_sfx_volume = sfx_value
	current_music_volume = music_value
	
	print("Loaded audio settings - SFX: " + str(sfx_value) + "%, Music: " + str(music_value) + "%")
	
	# Aplicar configuraciones
	set_volume("SFX", sfx_value)
	set_volume("Music", music_value)
	set_volume("Ambient", music_value) # Usa el mismo valor que la música

# Asegura que todos los valores de audio estén en 100% al inicio del juego
func force_default_audio_values():
	# Verificar si es la primera vez que se ejecuta el juego
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	# Si no existe un archivo de configuración o si está corrupto, establecer valores por defecto
	if err != OK:
		print("Estableciendo valores de audio por defecto (100%)")
		
		# Establecer todos los buses al 100%
		var buses = ["SFX", "Music", "Ambient", "Master"]
		for bus_name in buses:
			var bus_idx = AudioServer.get_bus_index(bus_name)
			if bus_idx != -1:
				AudioServer.set_bus_mute(bus_idx, false)
				AudioServer.set_bus_volume_db(bus_idx, linear2db(1.0)) # 100%
		
		# Guardar esta configuración como predeterminada
		config.set_value("audio", "sfx", 100)
		config.set_value("audio", "music", 100)
		config.save("user://settings.cfg")
		
		current_sfx_volume = 100
		current_music_volume = 100

# Forzar inicialización de buses - útil para llamar desde cualquier script
func force_initialize_buses():
	initialize_audio_buses()
	print("Buses de audio inicializados forzadamente")
	
	# También escanear y asignar buses a los AudioStreamPlayer existentes
	call_deferred("scan_existing_players")

# Función para configurar el volumen de un bus específico
func set_volume(bus_name, percent):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		# Silenciar completamente si el volumen es 0%
		if percent <= 0:
			AudioServer.set_bus_mute(bus_idx, true)
			print(bus_name + " muted completely")
		else:
			# Asegurarse de que el bus no esté silenciado
			AudioServer.set_bus_mute(bus_idx, false)
			# Convertir porcentaje a decibeles y aplicar
			var db_value = linear2db(percent / 100.0)
			AudioServer.set_bus_volume_db(bus_idx, db_value)
			print(bus_name + " volume set to " + str(percent) + "% (" + str(db_value) + "dB)")
	else:
		print("Error: Bus " + bus_name + " not found")

# Esta función fuerza el silencio en todos los buses si están en 0%
func force_audio_settings():
	# Verificar si hay configuración guardada
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		# No hay configuración guardada, usar valores predeterminados
		set_volume("SFX", 100)
		set_volume("Music", 100)
		set_volume("Ambient", 100)
		current_sfx_volume = 100
		current_music_volume = 100
		print("No config file - all audio buses set to 100%")
		return
	
	# Obtener valores guardados
	var sfx_value = config.get_value("audio", "sfx", 100)
	var music_value = config.get_value("audio", "music", 100)
	
	# Guardar en variables para uso futuro
	current_sfx_volume = sfx_value
	current_music_volume = music_value
	
	print("Forcing audio settings - SFX: " + str(sfx_value) + "%, Music: " + str(music_value) + "%")
	
	# Forzar la configuración a todos los buses, EXCEPTO Master
	# El bus SFX afecta a los efectos de sonido
	set_volume("SFX", sfx_value)
	
	# El bus Music afecta a la música de fondo
	set_volume("Music", music_value)
	set_volume("Ambient", music_value)
	
	# Asegurarse de que Master NO esté silenciado
	var master_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, false)
	AudioServer.set_bus_volume_db(master_idx, linear2db(1.0))
	
	# Escanear y asignar buses a los AudioStreamPlayer existentes
	call_deferred("scan_existing_players")

# Actualiza la configuración del bus como respuesta a una acción del usuario
func update_bus_volume(bus_name, percent):
	# Solo afectar al bus especificado sin afectar a los demás
	set_volume(bus_name, percent)
	
	# Actualizar variables de estado
	if bus_name == "SFX":
		current_sfx_volume = percent
	elif bus_name == "Music":
		current_music_volume = percent
	
	# Si el bus es "Music", también actualizar "Ambient" con el mismo valor para mantener consistencia
	if bus_name == "Music":
		set_volume("Ambient", percent)
		
	# Importante: Ya NO silenciamos el bus Master, para permitir
	# que cada control funcione de forma independiente
	# Es decir, si silencias SFX, la música sigue sonando y viceversa
	print(bus_name + " volume updated to " + str(percent) + "%")
	
	# Escanear y asignar buses a los AudioStreamPlayer existentes después de cambiar el volumen
	call_deferred("scan_existing_players")

# Reproduce un archivo de música
func play_music(stream):
	if MusicPlayer.stream == stream and MusicPlayer.playing:
		return
	
	MusicPlayer.stream = stream
	MusicPlayer.bus = "Music"
	MusicPlayer.play()

# Reproduce un efecto de sonido
func play_sfx(stream):
	SFXPlayer.stream = stream
	SFXPlayer.bus = "SFX"
	SFXPlayer.play()

# Reproduce un sonido ambiental
func play_ambiance(stream):
	AmbiancePlayer.stream = stream
	AmbiancePlayer.bus = "Ambient"
	AmbiancePlayer.play()

# Detiene la música
func stop_music():
	MusicPlayer.stop()

# Detiene los efectos de sonido
func stop_sfx():
	SFXPlayer.stop()

# Detiene los sonidos ambientales
func stop_ambiance():
	AmbiancePlayer.stop()

# Este método comprueba si hay reproductores silenciados que deban reactivarse
func reactivate_muted_players():
	# Si el volumen de música está por encima de 0, buscar reproductores silenciados para reactivarlos
	if current_music_volume > 0:
		print("Reactivando reproductores de música previamente silenciados")
		
		# Obtener el nodo raíz
		var root = get_tree().get_root()
		
		# Buscar todos los AudioStreamPlayer en la escena
		reactivate_players_in_node(root)
		
		# También reactivar la música principal si estaba silenciada
		if MusicPlayer.volume_db < -70 and not MusicPlayer.playing and MusicPlayer.stream != null:
			MusicPlayer.volume_db = 0
			MusicPlayer.play()
			print("Reactivado reproductor principal de música")

# Función recursiva para buscar y reactivar reproductores de audio en un nodo
func reactivate_players_in_node(node):
	# Si es un AudioStreamPlayer y está en el bus de música
	if node is AudioStreamPlayer and node.bus == "Music":
		# Si está silenciado pero debería estar sonando (tiene autoplay o volumen muy bajo)
		if node.volume_db < -70 or (node.autoplay and not node.playing):
			# Reactivar el reproductor
			node.volume_db = 0
			
			# Si no está reproduciendo pero debería estarlo
			if not node.playing and node.autoplay:
				node.play()
				print("Reactivado reproductor: " + node.name)
			elif node.volume_db < -70:
				print("Restaurado volumen para: " + node.name)
	
	# Revisar todos los nodos hijos
	for child in node.get_children():
		reactivate_players_in_node(child)
