class_name CarWheel extends StaticBody2D

const MAX_SPEED_FACTOR = 100 ##Base line value for slip calculation
const TRACTION_BUILD_FACTOR = 0.0001 ##How much rotatoinal force gets converted to traction
const FRICTION_BUILD_AMOUNT = 0.1 ##How fast friction is built per frame

var traction: float = 0.1 ##Arbitary value representing wheels "connectedness" to the ground
var friction: float = 0.0
var bodyPosition: Vector2 = Vector2(0,0) ##Wheels relative position to the car's body
var surfaceFriction = 0.1 ##0 is perfect ice 1 would be a race track
var speedCapacity = 200 ##Maximum change in velocity
var tractionLimit = 0.75
var breakingFriction: float = 0.0
var turningFriction: float = 0.0
#var friction = 0.5 ## 1 would represent driving on a perfectly smooth surface
var drifting = false ##Whether or not the wheel is turning the car
var torque = 0.0
var isSteeringWheel: float = false

@onready var DirtParticles: GPUParticles2D = $DirtEmitter
@onready var TrailParticles: GPUParticles2D = $TrailEmitter

@export var isDrivingWheel: bool = false ##Should this wheel affect acceleration vector?
@export var powerBias: float = 0.1 ##What percent of the power is delivered to this wheel? 0.1 to represent natural rolling of the wheel

func _ready():
	self.bodyPosition = self.position
	if get_parent().name == "FrontWheels":
		isSteeringWheel = true
		DirtParticles.emitting = false
		TrailParticles.emitting = false
		

func TransmitPower(rotationForce: float, _delta: float) -> Vector2:
	#Angular Change and speed change is handled in car_base.gd
	
	DirtParticles.emitting = true
	#var lateral_slip_factor = 50.0
	var tractionChange = rotationForce * surfaceFriction * TRACTION_BUILD_FACTOR
	traction += randf_range(tractionChange/10, tractionChange*10)
	if traction > tractionLimit:
		traction = tractionLimit
	#print("TRACTION CHANGE: ", tractionChange, " TRACTION: ", traction)
	
	if(rotationForce * powerBias >= speedCapacity):
		pass
		##Simulate Wheel Slip
		#var max_speed_change = self.speedCapacity * delta  # How much can the speed change this frame
		# Longitudinal Force (wheel spin)
		#var slip_ratio = (rotationForce / max_speed_change) - 1.0 
		#print(slip_ratio)
		#var longitudinal_slip = clamp(slip_ratio, 0.0, 5.0)  # Adjust the max slip
	
		# Lateral force (sideways slide)
		#var lateral_slip = min(slip_ratio, 1.0) * lateral_slip_factor # Adjust lateral_slip_factor

	torque = rotationForce
	return Vector2(0,0)

func RollWheel(_delta: float):
	var currentSpeed = Globals.SpeedToMPH(Globals.playerSpeed)
	_particleLogic(currentSpeed)
	
	
	friction = breakingFriction + turningFriction if breakingFriction + turningFriction < 1.0 else 1.0
	#print("WHEEL FRICTION: ", friction)
	
func CalculateSpeedCapacity() -> float:
	speedCapacity = traction * surfaceFriction * MAX_SPEED_FACTOR
	return speedCapacity

func _particleLogic(currentSpeed: float):
	if (abs(currentSpeed) < 1.0):
		#No particles
		DirtParticles.emitting = false
		TrailParticles.emitting = false
		return
		#
	#if (abs(torque) > 2.0 and traction < 0.4):
		#DirtParticles.emitting = true
		#TrailParticles.emitting = true
		#Heavy Particles
	else:
		DirtParticles.emitting = true
		TrailParticles.emitting = true
	#print("TORQUE: ",torque)
	return
