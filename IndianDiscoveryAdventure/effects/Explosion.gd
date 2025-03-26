extends Node2D

signal exploded

func _ready() -> void:
	#warning-ignore:return_value_discarded
	$AnimationPlayer.connect("animation_finished", self, "_on_Animation_finished")
	# Asegurarse que la explosión use el bus correcto de audio
	$AudioStreamPlayer2D.bus = "SFX"
	
	# Iniciar temporizador para liberar el objeto
	# Asegurarse de que el Timer existe primero
	if not has_node("Timer"):
		var timer = Timer.new()
		timer.name = "Timer"
		timer.one_shot = true
		timer.wait_time = 2.0 # 2 segundos hasta liberar
		add_child(timer)
	$Timer.start()

func start() -> void:
	$AnimationPlayer.play('Explode')
	$AudioStreamPlayer2D.play()

func _on_Animation_finished(anim_name: String) -> void:
	assert(anim_name == 'Explode')
	emit_signal('exploded')
	queue_free()
