extends Area2D

# Variables
var speed = 300
var direction = Vector2.RIGHT
var player = null
var damage = 5  # Daño que hace la bola de fuego

# Animaciones
onready var sprite = $Sprite
onready var collision_shape = $CollisionShape2D
onready var timer = $Timer

# Sonido
var fireball_sound_path = "res://sound/general-sounds/Curacocha_Attack/Fireball.wav"

func _ready():
	# Configurar animaciones
	timer.start()
	# Find player in the scene
	setup_player_tracking()
	
	# Conectar la señal para colisiones directamente con el Area2D
	connect("body_entered", self, "_on_Fireball_body_entered")
	
	# Reproducir sonido de bola de fuego
	play_fireball_sound()
	
	# Log success
	print("Fireball created at position: ", global_position)

# Reproducir el sonido de la bola de fuego
func play_fireball_sound():
	# Cargar y reproducir el sonido directamente
	var audio_stream = load(fireball_sound_path)
	if audio_stream:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = audio_stream
		audio_player.bus = "SFX"
		add_child(audio_player)
		audio_player.play()
		# Autodestruir después de reproducir
		yield(audio_player, "finished")
		audio_player.queue_free()

# Search for player through multiple methods
func setup_player_tracking():
	# Method 1: Try to find player in "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Fireball found player in 'player' group")
		return
		
	# Method 2: Try to find by node name
	player = get_tree().get_root().find_node("Player", true, false)
	if player:
		print("Fireball found player by name")
		return

	# Method 3: Try to find any KinematicBody2D that could be the player
	var bodies = get_tree().get_nodes_in_group("KinematicBody2D")
	if bodies.size() > 0:
		# Get the first body that isn't a Curacocha
		for body in bodies:
			if not "Curacocha" in body.name:
				player = body
				print("Fireball found potential player: ", body.name)
				break
	
	print("Fireball couldn't find any player")

func _process(delta):
	# If player wasn't found initially, keep trying
	if player == null:
		setup_player_tracking()
	
	# Update direction to follow player if player exists
	if player and is_instance_valid(player):
		direction = (player.global_position - global_position).normalized()
	
	# Mover bola de fuego
	position += direction * speed * delta
	
	# Optional: rotate the sprite to face the direction of movement
	if direction != Vector2.ZERO:
		sprite.rotation = direction.angle() + PI/2

# Manejo de colisiones directamente en la bola de fuego
func _on_Fireball_body_entered(body):
	print("Fireball colisionó con: " + body.name + " (" + str(body) + ")")
	
	if body.is_in_group("player") or body.name == "Player" or (player and body == player):
		print("¡Fireball impactó al jugador! Intentando causar ", damage, " de daño")
		
		# Usar el sistema de daño correcto para este juego
		# El sistema espera Health.take_damage(amount, direction)
		if body.has_node("Health"):
			var health_node = body.get_node("Health")
			if health_node.has_method("take_damage"):
				# Calcular la dirección del golpe (1 = derecha, -1 = izquierda)
				var hit_direction = 1
				if body.global_position.x < global_position.x:
					hit_direction = -1
				
				print("Aplicando ", damage, " de daño al nodo Health con dirección ", hit_direction)
				health_node.take_damage(damage, hit_direction)
			else:
				print("ERROR: El nodo Health no tiene el método take_damage")
		elif body.has_method("take_damage"):
			print("Usando método take_damage del cuerpo")
			body.take_damage(damage)
		else:
			print("ERROR: No se encontró método para hacer daño al jugador")
			# Imprimir métodos disponibles para depurar
			var methods = []
			for method in body.get_method_list():
				methods.append(method["name"])
			print("Métodos disponibles: ", methods)
		
		# Destruir la bola de fuego al impactar
		queue_free()
		
	# Si colisiona con algo que no es el jugador o Curacocha, también se destruye
	elif not (body.is_in_group("enemies") or "Curacocha" in body.name):
		print("Fireball impactó con otro objeto y se destruye")
		queue_free()

func _on_Timer_timeout():
	print("Fireball se destruye por timeout")
	queue_free()
