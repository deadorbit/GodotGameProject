extends CanvasLayer

@onready var startButton: Button = $MenuFirstStage/VBoxContainer/StartButton
@onready var optionsButton: Button = $MenuFirstStage/VBoxContainer/OptionsButton
@onready var mainMenuPlayer: AnimationPlayer = $MainMenuPlayer

signal PlayGame

# Called when the node enters the scene tree for the first time.
func _ready():
	startButton.grab_focus()
	

func _on_start_button_pressed():
	mainMenuPlayer.play("StageFirstToSecond")
