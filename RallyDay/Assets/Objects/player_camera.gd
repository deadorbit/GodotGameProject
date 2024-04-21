extends Camera2D
var minimumZoomLevel = 0.1
var maximumZoomLevel = 0.5
var speedMinThreshold = 10.0 ## Minimum speed needed for camera to begin zooming out
var speedMaxThreshold = 100.0 ## Speed at which camera is at max zoom out
var zoomFactorSpeed = 0.5
var lastZoomUpdateTime = 0
var zoomChangeDelay: int = 2
var targetZoom: float = 0.5
var cameraOffset: float
var originOffset
var aspectRatio
var desiredZoom

@onready var car: Node2D = get_parent()
@onready var carSprite: Sprite2D = car.get_node("CarHull")

# Called when the node enters the scene tree for the first time.
func _ready():
	var baseSize = Vector2(1152,648)
	var windowSize = Vector2(get_window().size.x,get_window().size.y)
	aspectRatio = windowSize / baseSize
	
	desiredZoom = zoom.y # Your baseline zoom from your reference setup
	zoom = Vector2(aspectRatio.x * desiredZoom, aspectRatio.y * desiredZoom)
	
	#cameraOffset = position.y
	
	#Step 1: get the pixel size of the default viewport by using (1/zoom.y) * get_viewport_getrect().size.y
	#var car_offset = carSprite.position.y
	#viewportHeight = get_viewport_rect().size.y * (1/zoom.y)
	#print(viewportHeight)
	##var viewportHalfHeight = (viewportHeight/2)
	##var viewportTopEdgetoNodeCenter = abs(position.y) + viewportHalfHeight
	#var spriteH = round(carSprite.get_rect().size.y * carSprite.scale.y)
	#var spriteOffsetY = carSprite.position.y
	#var CarPositiveYOffset = round(0 + (spriteH/2) - spriteOffsetY)
	#print(CarPositiveYOffset)
	##var viewportEdgeToSpriteTop = viewportTopEdgetoNodeCenter - CarPositiveYOffset
	##var viewportEdgeToSpriteEdge = viewportEdgeToSpriteTop + spriteH
	##spriteOffset = viewportHeight - viewportEdgeToSpriteEdge
	#cameraOffset = ((position.y + CarPositiveYOffset) / viewportHeight)/2
	#var spritePercentofViewportHeight = spriteBottomToViewPortEdge / viewportHeight
	#cameraPercentOffset = spriteBottomToViewPortEdge / viewportHeight
	#originOffset = cameraPercentOffset * position.y
	#print("SpriteHeight: ", spriteH, " Space to: ", spriteBottomToViewPortEdge, " Origin Offset: ", cameraPercentOffset)
	Globals.playerEngineChange.connect(SmoothZoom)
	zoom = Vector2(desiredZoom,desiredZoom)

func _CalculateCameraOffset():
	#(scale - offset)
	#var cameraYOffset
	#spriteOffset = 88.0
	#if (zoom.y == 0.5): #Handle zero Divisor
		#cameraYOffset = 0
	#else:
		#cameraYOffset = spriteOffset * (1.0/zoom.y)/2.0
		#
	#print(cameraYOffset)
		#
	#var cameraNewPosition = (((cameraOffset/2.0) * (1.0/zoom.y))) + cameraYOffset
	##position.y = cameraNewPosition
	#print(cameraNewPosition)
	#print(cameraOffset)
	var cameraOffest = remap(zoom.y,0.1, 0.5, -1200.0, -400.0)
	#print("ZOOM: ", zoom.y, " OFFSET: ", cameraOffest)
	
	#var input_value = -zoom.y  # Your input value
	#var output_value
	#if(input_value < -0.5):
		#output_value = lerp(0.5, 1.0, remap(input_value,-1.0, -0.5, 0.0, 1.0))
		#print(output_value)
	#else:
		#output_value = lerp(1.0, 2.0, remap(input_value,-0.5, -0.25, 0.0, 1.0))
		#print(output_value)
	#
	#var viewportSize = get_viewport_rect().size.y * 2
	#print(viewportSize)
	#print("OFFSET: ", cameraOffset)
	#
	#print((viewportSize * (output_value * cameraOffset)))
	position.y = cameraOffest

func SmoothZoom():
	var speed = Globals.SpeedToMPH(Globals.playerSpeed)
	zoom = lerp(zoom, Vector2(targetZoom,targetZoom), zoomFactorSpeed * get_process_delta_time())
	_CalculateCameraOffset()
	
	var currentTime = (Time.get_ticks_msec() / 1000.0)
	#print("CURRENT TIME: ", currentTime, " LAST TIME: ", lastZoomUpdateTime, " TIME CHANGE: ", currentTime - lastZoomUpdateTime)
	if currentTime - lastZoomUpdateTime < zoomChangeDelay:
		return
	
	speed = clamp(speed, speedMinThreshold, speedMaxThreshold)
	speed = remap(speed, speedMinThreshold, speedMaxThreshold, maximumZoomLevel, minimumZoomLevel)
	targetZoom = (speed)
#
	#targetZoom = clamp(targetZoom,minimumZoomLevel,maximumZoomLevel)
	#print("TARGET ZOOM:", targetZoom, " SPEED: ", speed)
	##var targetZoom = clamp(remap(speed, speedMinThreshold, speedMaxThreshold, maximumZoomLevel, minimumZoomLevel), minimumZoomLevel, maximumZoomLevel) 
#
	## Update the time of the last zoom change
	lastZoomUpdateTime = currentTime
