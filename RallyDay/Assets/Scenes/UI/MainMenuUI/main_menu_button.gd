extends Button

@onready var menuPlayer: AnimationPlayer = $MenuButtonPlayer

func _on_focus_entered():
	menuPlayer.play("scale")
	

func _on_focus_exited():
	menuPlayer.stop()
	

func _on_mouse_entered():
	grab_focus()
