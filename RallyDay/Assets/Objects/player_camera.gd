extends Camera2D
var minimumZoomLevel = 0.1
var maximumZoomLevel = 0.5
var speedMinThreshhold = 50 ## Minimum speed needed for camera to begin zooming out
var speedMaxThreshold = 180 ## Speed at which camera is at max zoom out
var zoomFactorSpeed = 0.5

# Called when the node enters the scene tree for the first time.
func _ready():
	Globals.connect("playerEngineChange",SmoothZoom)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func SmoothZoom():
	print("Zooming")
	var playerDelta = Globals.playerDelta
	var speed = Globals.playerSpeed
	
