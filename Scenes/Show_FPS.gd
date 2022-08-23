extends Node

func _on_Show_FPS_pressed():
	print(Engine.get_frames_per_second())
	Global.ShowFPS = !Global.ShowFPS
	print(Global.ShowFPS)
