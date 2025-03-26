"""
Damage zone made to work with a slash effect.
@extends DamageZone
"""
extends DamageZone
class_name SlashDamageZone

# Sent to slash to display the good slash effect
export(String) var type_of_attack := 'Light' setget set_type_of_attack

"""
Set damage and display slash effect
@param {Character} body - a character
"""
func _on_Body_entered(body) -> void:  
	#	ennemy and player - verificaciu00f3n segura de propiedades
	if body and (body.get("is_invincible") == null or not body.is_invincible):
		.make_damage(body)
		# Verificar si existe el nodo Slash antes de llamarlo
		var parent = get_parent()
		if parent and parent.has_node('Slash'):
			parent.get_node('Slash').slash(type_of_attack)
	
"""
Type of attack will decide wich slash will be displayed.
@param {string} type - light, medium or heavy
"""
func set_type_of_attack(type: String) -> void:
	type_of_attack = type
