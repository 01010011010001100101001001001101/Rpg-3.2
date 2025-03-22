extends Control

export(String) var scene_path = ''


func _ready() -> void:
	$Bg/opciones/VBoxContainer/Play.connect("pressed",self, "_on_Play_pressed")
	$Bg/opciones/VBoxContainer/Options.connect("pressed", self, "_on_Options_pressed")
	$Bg/opciones/VBoxContainer/Quit.connect("pressed", self, "_on_Quit_pressed")
	

func _on_Play_pressed() -> void:
	LevelManager.goto_scene('res://scenes/%s.tscn' % [scene_path])


func _on_Options_pressed() -> void:
	get_tree().change_scene('res://interfaces/menu/Options.tscn')
	
	
func _on_Quit_pressed() -> void:
	get_tree().quit()
