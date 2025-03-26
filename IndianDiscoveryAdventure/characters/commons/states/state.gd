#warning-ignore-all:unused_argument
#warning-ignore-all:unused_signal

"""
Base interface for all states: it doesn't do anything in itself
but forces us to pass the right arguments to the methods below
and makes sure every State object had all of these methods.

It's someking of abstract class.
Only play_sound does something
"""
extends Node
class_name State

# signal emitted when a the state is over
signal finished(next_state_name)


func _ready():
	set_process(false)
	set_physics_process(false)
	set_process_input(false)


"""
Initialize the state. E.g. change the animation
"""
func enter(host):
	pass


""" 
Clean up the state. Reinitialize values like a timer
"""
func exit(host):
	pass


"""
Handle input
"""
func handle_input(host, event):
	pass


"""
Use in th same style has the process funtion
"""
func update(host, delta: float):
	pass


"""
Call when AnimationPlayer emit _on_Animation_finished.

@param {string} anim_name
@param {object} host
"""
func _on_Animation_finished(anim_name: String, host):
	pass

"""
Ceneric play_sound function.

@param {object} host
@param {resource} stream
"""
func play_sound(host, stream: Resource) -> void:
	host.get_node('AudioStreamPlayer').stream = stream
	host.get_node('AudioStreamPlayer').bus = "SFX"
	host.get_node('AudioStreamPlayer').play()

func play_audio(stream: AudioStream, override: bool = false):
	# Verificar primero si se pasó 'self' como argumento
	if not self.has_method("get_node"):
		return
		
	if not self.has_node('AudioStreamPlayer') or stream == null:
		return
	
	var player = self.get_node('AudioStreamPlayer')
	if not player.playing or override:
		player.stream = stream
		# Asignar al bus de efectos de sonido
		player.bus = "SFX"
		player.play()
