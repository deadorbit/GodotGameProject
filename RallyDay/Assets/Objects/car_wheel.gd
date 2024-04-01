class_name CarWheel extends StaticBody2D

const MAX_SPEED_FACTOR = 1000

var traction: float = 0 ##Arbitary value representing wheels "connectedness" to the ground
var bodyPosition: Vector2 = Vector2(0,0) ##Wheels relative position to the car's body
var surfaceFriction = 0.25 ##Frictional value of the current surface the wheel is on, 1 would represent bringing the wheel to a complete stop instantly
var speedCapacity = 200 ##Maximum change in velocity
var friction = 0.5 ## 1 would represent driving on a perfectly smooth surface

@onready var DirtParticles: GPUParticles2D = $DirtEmitter

@export var isDrivingWheel: bool = false ##Should this wheel affect acceleration vector?
@export var powerBias: float = 0.1 ##What percent of the power is delivered to this wheel? 0.1 to represent natural rolling of the wheel

func _ready():
	self.bodyPosition = self.position

func TransmitPower(power, delta):
	pass
	#traction = traction + power
	#if traction > 1.0:
		#traction = 1.0
	#if traction < 0.5 and isDrivingWheel:
		#DirtParticles.emitting = true
		##DirtParticles.amount_ratio = ((1 - traction) * 25)
	#else:
		#DirtParticles.emitting = false

func RollWheel():
	pass


func CalculateSpeedCapacity (averageCarTraction: float) -> float:
	return traction * averageCarTraction * MAX_SPEED_FACTOR
