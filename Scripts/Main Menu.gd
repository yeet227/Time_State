extends Control

# Called when the node enters the scene tree for the first time.
#func _ready():
#	for button in $"Label/".get_children():
#		button.connect("pressed", self, "_on_Button_pressed", [button.scene_to_load])


func _on_Button_pressed(scene_to_load):
	print("Changing Scene...")
	print(scene_to_load)
	get_tree().change_scene(scene_to_load)
	print("Scene_Loaded")
