extends Node

func _on_Show_FPS_pressed():
	print(Engine.get_frames_per_second()) #This particular function retrives the frame rate data and outputs the data to the output logger
	Global.ShowFPS = !Global.ShowFPS #Connecting to the Global Script regarding either False or True Statements to enable button to read the games frame rate from the Output Logger
#	print(Global.ShowFPS) Debuggin Purposes to see the the Boolean Works
