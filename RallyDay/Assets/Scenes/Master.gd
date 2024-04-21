extends Node2D

@onready var LoadingUI: PackedScene = preload("res://Assets/Scenes/UI/Loading/LoadingUI.tscn")
@onready var initalScene: CanvasLayer = $LoadingUi
@onready var mainMenuScene: PackedScene = preload("res://Assets/Scenes/Phases/MainMenu.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	var loadingPlayer: AnimationPlayer = initalScene.get_node("LoadingPlayer")
	var mainMenu = mainMenuScene.instantiate()
	add_child(mainMenu)
	var mainMenuUI: CanvasLayer = mainMenu.get_node("MainMenuUI")
	mainMenuUI.connect("PlayGame", _PlayGame)
	
	loadingPlayer.play("FadeOut")
	
func _PlayGame():
	print("PlayPressed")
