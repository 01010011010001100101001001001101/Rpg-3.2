extends Node

class_name Atack

# Señales para el cambio de estado
signal finished(next_state_name)

# Variables
var attack_timer = 0.0
var attack_cooldown = 2.0

# Sonido
var attack_sound_path = "res://sound/general-sounds/Curacocha_Attack/Curacocha_attack.wav"

func enter(host) -> void:
	# Reproducir animación de ataque
	host.animated_sprite.play("attack")
	# Si no existe una animación de ataque, usar otra animación
	if not host.animated_sprite.get_animation() == "attack":
		host.animated_sprite.play("idle")
	
	# Reproducir sonido de ataque
	play_attack_sound()
	
	# Realizar el ataque
	shoot_fireball(host)
	
	# Iniciar temporizador para siguiente ataque
	attack_timer = attack_cooldown
	
	# Desactivar la capacidad de atacar hasta que termine el cooldown
	host.can_attack = false

# Reproducir el sonido de ataque de Curacocha
func play_attack_sound():
	# Alternativa directa sin usar AudioManager
	var audio_stream = load(attack_sound_path)
	if audio_stream:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = audio_stream
		audio_player.bus = "SFX"
		add_child(audio_player)
		audio_player.play()
		# Autodestruir después de reproducir
		yield(audio_player, "finished")
		audio_player.queue_free()

# Actualizar estado
func update(host, delta: float) -> void:
	# Actualizar temporizador
	attack_timer -= delta
	
	# Si ha terminado el cooldown, habilitar otro ataque
	if attack_timer <= 0:
		host.can_attack = true
		
		# Comprobar si el objetivo está aún dentro del rango de ataque
		var distance_to_target = host.global_position.distance_to(host.target_position)
		if distance_to_target <= 200.0 and host.has_target: # ATTACK_RANGE
			# Si está en rango y puede atacar, hacer otro ataque
			# Reproducir sonido de ataque nuevamente
			play_attack_sound()
			shoot_fireball(host)
			attack_timer = attack_cooldown
		else:
			# Si no está en rango, cambiar al estado de seguimiento
			emit_signal('finished', 'Follow')

func shoot_fireball(host) -> void:
	if host.fireball_scene:
		var fireball = host.fireball_scene.instance()
		fireball.global_position = host.global_position
		
		# Asegurar que la bola de fuego se dispare en la dirección del objetivo
		if host.has_target:
			var direction = (host.target_position - host.global_position).normalized()
			# Asignar dirección a la bola de fuego (asumiendo que el script de fireball tiene una variable direction)
			if fireball.has_method("set_direction"):
				fireball.set_direction(direction)
			elif fireball.get("direction") != null:
				fireball.direction = direction
		
		# Añadir la bola de fuego a la escena
		host.get_parent().add_child(fireball)
