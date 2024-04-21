extends Node2D

@onready var cameraNode: Node2D = $CameraNode
@onready var mainMenuCam: Camera2D = $CameraNode/MainMenuCamera

var orbitRotation = 0.0
var orbitSpeed = 30.0
var cameraOffset = Vector2(0, 500)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	orbitRotation += (orbitSpeed * delta)
	cameraNode.position = cameraOffset.rotated(deg_to_rad(orbitRotation))
