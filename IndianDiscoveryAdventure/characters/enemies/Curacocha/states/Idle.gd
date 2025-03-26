extends Node

class_name Idle

# Señales para el cambio de estado
signal finished(next_state_name)

func enter(host) -> void:
	# Reproducir animación de inactivo
	host.animated_sprite.play("idle")
	# Detener movimiento horizontal
	host.velocity.x = 0

func update(host, delta: float) -> void:
	# Si tiene un objetivo, cambiar al estado de seguimiento
	if host.has_target:
		emit_signal('finished', 'Follow')
