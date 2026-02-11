extends Area2D


#type the name of the next map in the inspector!
@export_file("*.tscn") var target_map_path
@export var spawn_location_name: String #name of the Marker2D here
@export_enum("up", "down", "left", "right") var spawn_direction: String = "down"

func _on_body_entered(body):
	if body.name == "Player":
			Global.target_spawn_name = spawn_location_name
			Global.target_direction = spawn_direction
			get_tree().change_scene_to_file(target_map_path)
