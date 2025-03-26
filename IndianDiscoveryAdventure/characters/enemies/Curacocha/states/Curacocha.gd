extends KinematicBody2D

# Variables
var speed = 100
var gravity = 20
var velocity = Vector2()
var on_ground = false
var fireball_scene = null
var health = 15  # Reducir aún más la salud para que muera con un solo golpe
var alive = true # Variable para controlar si Curacocha está vivo
var damage_multiplier = 3.0  # Multiplicador de daño recibido
var is_invincible = false  # Agregar esta propiedad para compatibilidad con el sistema de daño

# Variables para la IA
var has_target = false
var target_position = Vector2()
var can_attack = true
var player = null  # Referencia directa al jugador

# Variables para animaciones - usar un sistema de estados simple
var current_state = "idle" # idle, run, walk, attack
var attack_timer = 0.0
var attack_cooldown = 0.0
var attack_state_duration = 1.5

# Referencia a componentes
onready var animated_sprite = $AnimatedSprite
onready var health_node = $Health if has_node("Health") else null
onready var audio_player = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

# Variables para el rango de movimiento
var start_position = Vector2()
var move_direction = 1  # 1 derecha, -1 izquierda
var patrol_time = 0
var patrol_duration = 2.0  # Segundos moviéndose en una dirección

# Para manejo de knockback - compatibilidad con el sistema de daño
var knockback_force = Vector2()

# Asegurarse de imprimir mensajes para depuración
func _ready():
	print("Curacocha iniciado")
	
	# Asegurarse de que esté en la capa de colisión correcta para recibir daño
	set_collision_layer_bit(2, true) # Establecer capa 3 (valor 4 en máscara)
	
	# Guardar posición inicial
	start_position = global_position
	
	# Cargar la escena de bola de fuego
	fireball_scene = load("res://characters/enemies/Curacocha/fireball.tscn")
	if not fireball_scene:
		push_error("No se pudo cargar fireball.tscn")
	
	# Buscar jugador
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		has_target = true
	else:
		# Buscar por nombre si no está en el grupo
		var possible_player = get_tree().get_root().find_node("Player", true, false)
		if possible_player:
			player = possible_player
			has_target = true
	
	# Conectar señales de salud
	if health_node:
		# Desconectar cualquier conexión existente para evitar duplicados
		if health_node.is_connected("take_damage", self, "_on_Health_take_damage"):
			health_node.disconnect("take_damage", self, "_on_Health_take_damage")
		
		# Reconectar la señal
		health_node.connect("take_damage", self, "_on_Health_take_damage")
		
		# Establecer la salud inicial
		if health_node.has_method("init"):
			health_node.init(health, health)
	
	# Forzar animación inicial
	_change_animation("idle")


# Función para permitir que el sistema de daño funcione con Curacocha
func get_global_position():
	return global_position


func _change_animation(anim_name):
	if animated_sprite and animated_sprite.frames.has_animation(anim_name):
		# Forzar animación incluso si es la misma - reinicia el frame
		animated_sprite.stop()
		animated_sprite.animation = anim_name
		animated_sprite.play()
		current_state = anim_name
		print("Cambiando animación a: " + anim_name)
	else:
		print("No se pudo cambiar a animación: " + anim_name)


func _physics_process(delta):
	# Si está muerto, no procesar lógica de movimiento
	if not alive:
		# Hacer que caiga al suelo si está muerto
		velocity.y += gravity
		velocity = move_and_slide(velocity, Vector2.UP)
		return
	
	# Aplicar knockback si existe
	if knockback_force != Vector2.ZERO:
		velocity = knockback_force
		knockback_force = Vector2.ZERO
	
	# Manejar cooldown de ataque
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Manejar duración del estado de ataque
	if current_state == "attack":
		attack_timer += delta
		if attack_timer >= attack_state_duration:
			attack_timer = 0
			_change_animation("idle")
	
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += gravity
	
	# Sólo actualizar movimiento si no está atacando
	if current_state != "attack":
		if has_target and player:
			# Seguir al jugador
			var direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * speed
			
			# Actualizar orientación del sprite
			if animated_sprite:
				animated_sprite.flip_h = direction.x < 0
			
			# Atacar si está a distancia
			var distance = global_position.distance_to(player.global_position)
			if distance <= 200 and attack_cooldown <= 0:
				_attack()
			
			# Actualizar animación según velocidad
			if current_state != "attack" and abs(velocity.x) > 10:
				_change_animation("run")
			elif current_state != "attack" and current_state != "idle":
				_change_animation("idle")
		else:
			# Patrullar cuando no hay jugador
			patrol_time += delta
			if patrol_time >= patrol_duration:
				patrol_time = 0
				move_direction *= -1
			
			velocity.x = speed * move_direction
			
			# Actualizar orientación del sprite
			if animated_sprite:
				animated_sprite.flip_h = move_direction < 0
			
			# Actualizar animación según velocidad
			if current_state != "attack" and abs(velocity.x) > 10:
				_change_animation("walk")
			elif current_state != "attack" and current_state != "idle":
				_change_animation("idle")
	
	# Mover enemigo
	velocity = move_and_slide(velocity, Vector2.UP)


func _attack():
	print("¡Curacocha ataca!")
	
	# Cambiar a animación de ataque
	attack_timer = 0
	_change_animation("attack")
	
	# Disparar fireball
	shoot_fireball()
	
	# Establecer cooldown
	attack_cooldown = 2.5


func shoot_fireball():
	if not fireball_scene:
		return null
	
	print("Disparando fireball...")
	var fireball = fireball_scene.instance()
	
	# Calcular posición inicial y dirección
	var start_pos = global_position
	start_pos.x += 30 * (1 if not animated_sprite.flip_h else -1)
	start_pos.y -= 20
	fireball.global_position = start_pos
	
	# Establecer dirección si hay jugador
	if has_target and player:
		var direction = (player.global_position - start_pos).normalized()
		
		# Asignar dirección según la implementación de fireball
		if fireball.has_method("set_direction"):
			fireball.set_direction(direction)
		elif fireball.get("direction") != null:
			fireball.direction = direction
	
	# Añadir a la escena
	get_tree().get_root().add_child(fireball)
	return fireball


func _on_Health_take_damage(is_alive, direction):
	print("Curacocha recibió daño. Está vivo: ", is_alive)
	
	# Simular un knock-back cuando recibe daño solo si está vivo
	if is_alive:
		velocity.x = direction * 200
		velocity.y = -150
	
	if not is_alive:
		# Proceso de muerte
		print("¡Curacocha ha sido derrotado!")
		alive = false
		
		# Detener todo movimiento
		velocity = Vector2.ZERO
		
		# Desactivar gravedad
		gravity = 0
		
		# Cambiar animación antes de morir si hay una
		if animated_sprite and animated_sprite.frames.has_animation("death"):
			_change_animation("death")
		else:
			# Detener cualquier animación actual
			if animated_sprite:
				animated_sprite.stop()
		
		# Desactivar colisiones
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		
		# Mostrar explosión
		if has_node("States/Death/Explosion"):
			var explosion = $States/Death/Explosion
			explosion.visible = true
			if explosion.has_method("start"):
				explosion.start()
				
			# Esperar brevemente a que se vea la explosión
			yield(get_tree().create_timer(0.5), "timeout")
			
			# Hacer invisible a Curacocha (desaparece)
			self.visible = false
			
			# Dejar que la explosión termine antes de eliminar completamente
			yield(get_tree().create_timer(1.0), "timeout")
		else:
			# Si no hay explosión, desaparecer directamente
			self.visible = false
			yield(get_tree().create_timer(0.5), "timeout")
		
		# Destruir objeto
		queue_free()


# Interceptamos el daño antes de pasarlo al sistema de salud para aumentarlo
func take_damage(amount):
	print("Curacocha take_damage llamado con: ", amount)
	
	# Aplicar multiplicador de daño
	var amplified_damage = amount * damage_multiplier
	print("Daño amplificado: ", amplified_damage, " (original: ", amount, ")")
	
	if health_node and health_node.has_method("take_damage"):
		# Usar el nodo Health con daño amplificado
		health_node.take_damage(amplified_damage, -1 if animated_sprite.flip_h else 1)
	else:
		# Manejar directamente
		health -= amplified_damage
		print("Curacocha recibió daño: " + str(amplified_damage) + ". Salud restante: " + str(health))
		
		if health <= 0 and alive:
			# Proceso de muerte
			alive = false
			print("Curacocha murió por daño directo")
			
			# Desactivar colisiones
			if has_node("CollisionShape2D"):
				$CollisionShape2D.set_deferred("disabled", true)
			
			# Mostrar explosión
			if has_node("States/Death/Explosion"):
				var explosion = $States/Death/Explosion
				explosion.visible = true
				if explosion.has_method("start"):
					explosion.start()
				
				# Esperar brevemente a que se vea la explosión
				yield(get_tree().create_timer(0.5), "timeout")
				
				# Hacer invisible a Curacocha (desaparece)
				self.visible = false
				
				# Dejar que la explosión termine antes de eliminar completamente
				yield(get_tree().create_timer(1.0), "timeout")
			else:
				# Si no hay explosión, desaparecer directamente
				self.visible = false
				yield(get_tree().create_timer(0.5), "timeout")
			
			# Destruir objeto
			queue_free()

# Función para debugging - para probar la muerte directamente
func kill():
	if alive:
		take_damage(health + 1)
