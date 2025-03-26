extends Node

class_name Follow

# Señales para el cambio de estado
signal finished(next_state_name)

# pixels/sec
export (float) var SPEED := 50
export (float) var ACCELERATION := 1

# Rangos
const TARGET_MIN_DISTANCE = 20.0
const FOLLOW_RANGE = 100.0  # Distancia máxima para seguir al jugador
const ATTACK_RANGE = 200.0  # Distancia para atacar
const MOVEMENT_LIMIT = 150.0  # Límite de movimiento desde posición inicial

# Referencia a la posición inicial
var initial_position = Vector2()

func enter(host) -> void:
	# Guardar la posición inicial cuando inicia el estado de seguimiento
	initial_position = host.global_position
	# Reproducir animación de movimiento
	host.animated_sprite.play("run")

func update(host, delta: float) -> void:
	if not host.has_target:
		# Si no hay objetivo, cambiar a estado inactivo
		emit_signal('finished', 'Idle')
	else:
		# Seguir al objetivo
		follow(host)

func follow(host) -> void:
	# Calcular dirección hacia el objetivo
	var target_direction = (host.target_position - host.global_position).normalized() 
	
	# Actualizar dirección del sprite
	if target_direction.x < 0:
		host.animated_sprite.flip_h = true
	else:
		host.animated_sprite.flip_h = false
	
	# Calcular distancias
	var distance_to_target = host.global_position.distance_to(host.target_position)
	var distance_to_initial = host.global_position.distance_to(initial_position)
	
	# Verificar si está dentro del rango de ataque
	if distance_to_target <= ATTACK_RANGE and host.can_attack:
		# Si está en rango de ataque y puede atacar, cambiar al estado de ataque
		emit_signal('finished', 'Attack')
	
	# Verificar si debe seguir al objetivo (dentro del rango y no muy lejos de la posición inicial)
	elif distance_to_target > TARGET_MIN_DISTANCE and distance_to_target < FOLLOW_RANGE and distance_to_initial < MOVEMENT_LIMIT:
		# Mover hacia el objetivo con aceleración
		host.velocity.x = lerp(host.velocity.x, target_direction.x * SPEED, ACCELERATION)
		# Asegurar que la animación es la correcta
		host.animated_sprite.play("run")
	else:
		# Detenerse si está muy cerca o fuera de rango
		host.velocity.x = 0
		emit_signal('finished', 'Idle')
