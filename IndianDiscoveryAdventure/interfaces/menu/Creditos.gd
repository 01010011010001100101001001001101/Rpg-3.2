extends Control

func _ready():
	$ButtonContainer/SalirButton.connect("pressed", self, "_on_SalirButton_pressed")
	$ButtonContainer/MenuButton.connect("pressed", self, "_on_MenuButton_pressed")
	
	print("Script de Creditos cargado correctamente")

func _on_SalirButton_pressed():
	print("Salir presionado")
	get_tree().quit()

func _on_MenuButton_pressed():
	print("Menu Principal presionado")
	
	# Detener cualquier música o sonido
	if has_node("Ambiance/Music"):
		$Ambiance/Music.stop()
	
	# Desconectar las señales
	$ButtonContainer/SalirButton.disconnect("pressed", self, "_on_SalirButton_pressed")
	$ButtonContainer/MenuButton.disconnect("pressed", self, "_on_MenuButton_pressed")
	
	# Eliminar todos los nodos hijos
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	# Usar el método más directo de Godot
	print("Cambiando directamente a MainMenu")
	get_tree().change_scene("res://interfaces/menu/MainMenu.tscn")
	
	# Forzar limpieza de memoria
	self.queue_free()
