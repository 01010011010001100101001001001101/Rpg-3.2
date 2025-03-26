"""
Manage damage on a character.
When touched, a knockback force is apply to the character.
"""
extends Area2D
class_name DamageZone

#warning-ignore:unused_class_variable
export(float) var amount := 20.0 setget set_amount
export(int, FLAGS) var MASK := 2
export(Vector2) var KNOCKBACK_FORCE := Vector2(5, 0)


func _ready():
	self.connect('body_entered', self, '_on_Body_entered')


"""
Set damage and display slash effect
@param {Character} body - a character
"""
func _on_Body_entered(body) -> void:  
	# Verificación de seguridad completa antes de intentar acceder a propiedades
	if body and (body.get("is_invincible") == null or not body.is_invincible):
		make_damage(body)
	

"""
Knockback character
"""
func make_damage(body) -> void:  
	# Verificar que body tiene las propiedades necesarias
	if not body or not body.has_method("get_global_position"):
		print("Error: El objeto no tiene el método get_global_position")
		return
	
	# Calcular dirección del golpe
	var direction: int = -1
	if body.get_global_position() > get_parent().get_global_position():
		direction = -1
	else:
		direction = 1
	
	# Aplicar knockback si el objeto lo soporta
	if body.get("knockback_force") != null:
		body.knockback_force = KNOCKBACK_FORCE
	
	# Verificar que body tiene un nodo Health
	if body.has_node("Health"):
		body.get_node('Health').take_damage(amount, direction)
	elif body.has_method("take_damage"):
		# Llamar directamente si existe el método
		body.take_damage(amount)
	else:
		print("Error: El objeto no tiene sistema de salud")


"""
Damage amount for the hitted character.
"""
func set_amount(new_amount):
	amount = new_amount
