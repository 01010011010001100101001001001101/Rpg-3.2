extends Control

func _ready():
	$Bg/Volver.connect('pressed', self, '_on_Pressed')
	

func _on_Pressed():
	get_tree().change_scene('res://interfaces/menu/MainMenu.tscn')
