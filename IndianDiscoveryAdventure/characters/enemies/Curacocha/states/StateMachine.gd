extends Node

class_name StateMachine

# Path to the initial active state
export(NodePath) var START_STATE
var states_map = {}

var states_stack = []
var current_state = null
var _active = false

# States are always processed through the state machine
func _ready():
	if not START_STATE:
		START_STATE = get_child(0).get_path()
		
	for child in get_children():
		if child.has_signal("finished"):
			child.connect("finished", self, "_change_state")
			if child.name:
				states_map[child.name] = child
				
	# El estado inicial comienza deactivado
	initialize(START_STATE)


func initialize(start_state):
	set_active(true)
	states_stack.push_front(get_node(start_state))
	current_state = states_stack[0]
	current_state.enter(get_parent())


func set_active(value):
	_active = value
	set_physics_process(value)
	set_process_input(value)
	if not _active:
		states_stack = []
		current_state = null


func _input(event):
	current_state.handle_input(get_parent(), event)


func _physics_process(delta):
	current_state.update(get_parent(), delta)


func _change_state(state_name):
	if not _active:
		return
	
	if state_name in states_map:
		var new_state = states_map[state_name]
		
		current_state.exit(get_parent())
		
		if state_name == 'Previous':
			states_stack.pop_front()
		else:
			states_stack[0] = new_state
		
		current_state = new_state
		
		if state_name != 'Previous':
			current_state.enter(get_parent())
