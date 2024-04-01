extends CharacterBody2D

const ROTATION_SENSITIVITY: float = 0.05 #How fast body should turn towards wheels
const MAX_ROTATION_SPEED: float = 15.0  #Maximum rate at which body can turn towards wheel angle
const SMOOTH_FACTOR: float = 1.2 #How fast wheels turn towards the target angle
const ANGULAR_INFLUENCE = 0.25 #How much differences in traction can "turn" the car
const ACCELERATION_RATE = 0.25  # Adjust this for how quickly the car accelerates
const FRICTION_COEFFICENT = 1
const SPEED_FACTOR = 50 ## Adjust this to change raw power values of engine
const MAX_TORQUE = 5.0 ## Hard limit on the maximal rotational velocity that can be achieved
const TORQUE_FACTOR = 0.05 ## Changes effectviness of rotating the body
const BASE_ANGULAR_FRICTION = 5 ## decrease in rotational velocity over over

@export var turn_speed: int ## Maximum turn speed of car wheels towards user input
@export var maxSteeringAngle: int
@export var RPMCurve: Curve
@export var gearRatios: Array
@export var RPMLimit: int
@export var enginePower: float
@export var bodyWeight: int
@export var maxSpeed: int
@export var RPMGauge: CompressedTexture2D
@export var RPMNeedle: CompressedTexture2D
@export var RPMLight: CompressedTexture2D
@export var SpeedometerGauge: CompressedTexture2D
@export var SpeedometerNeedle: CompressedTexture2D
@export var SpeedometerElectronic: CompressedTexture2D
@export var maxRPMGaugeAngle: int
@export var maxSpeedometerAngle: int

var Menu

@onready var frontWheels: Node2D = $FrontWheels
@onready var rearWheels: Node2D = $RearWheels
@onready var UI: PackedScene = preload("res://Interface.tscn")
@onready var root = get_node("/root")

var userSteering = 0.0  # Stores user input (-1 to 1)
var SimEngine: EngineNode
var userThrottle: float = 0.0
var speed: float = 0.0
var averageFriction: int = 0
var previousVelocity = Vector2(0,0)
var allWheels: Array

#Variables to create arbitary speed value
var currentSpeed = 0.0

#Controls turning momentum
var angularVelocity = 0.0
var momentOfIntertia = bodyWeight * 12 # Resistance of car to turning

#Debug
var visualizeLines: bool = true
@onready var debug = $Debug
var velocityLine: Line2D
var wheelLine: Line2D

func _ready():
	#Create Engine Object based off car object data
	SimEngine = EngineNode.new(gearRatios, RPMLimit, RPMCurve, enginePower)
	Globals.playerEngine = SimEngine
	
	
	position = get_viewport_rect().get_center()
	
	allWheels = frontWheels.get_children() + rearWheels.get_children()
	
	#Create car menu
	Menu = UI.instantiate()
	root.add_child.call_deferred(Menu)
	
	Globals.playerMaxRPMGaugeAngle = maxRPMGaugeAngle
	Globals.playerMaxSpeedometerAngle = maxRPMGaugeAngle
	var UIRPMGauge = Menu.get_node("RPMGauge")
	var UIRPMNeedle = UIRPMGauge.get_node("Needle")
	var UIRPMLight = UIRPMGauge.get_node("Light")
	UIRPMGauge.texture = RPMGauge
	UIRPMNeedle.texture = RPMNeedle
	UIRPMLight.texture = RPMLight
	
	if(visualizeLines):
		var debugNode = Node2D.new()
		root.add_child.call_deferred(debugNode)
		debugNode.name = "DebugLines"
		
		velocityLine = debug.get_node("VelocityAngle").duplicate()
		debugNode.add_child(velocityLine)
		wheelLine = debug.get_node("WheelAngle").duplicate()
		debugNode.add_child(wheelLine)
	
	#frontWheels.get_node("LeftWheel").traction = 0.1

func _physics_process(delta):
	handle_user_input()
	
	Globals.playerDelta = delta
	Globals.playerEngineChange.emit()
	var power = SimEngine.EngineLogic(userThrottle, delta) * SPEED_FACTOR
	var force = _AccelerateCar(power, delta)
	
	velocity = force
	previousVelocity = force
	
	#_Differental(allWheels)
	
	var velocityMagnitude = velocity.length()
	Globals.playerSpeed = int((velocityMagnitude/20))
	
	rotation_degrees = _RotateBody((velocityMagnitude * ROTATION_SENSITIVITY) / SPEED_FACTOR, delta)
	move_and_slide()

func _CalculateInverseForces(): #Calculate forces that would slow down the car (Friction/Drag/ect.)
	pass

func VisualizeAngle(line: Line2D, start_point: Vector2, angle: float, length):
	var end_point = start_point + Vector2(length, 0).rotated(deg_to_rad(angle))
	line.points = [start_point, end_point]  # Update Line2D points
	

func _ForceToMPH(forceValue):
	return forceValue.length() / 20

##Function which handles calculating velocity changes
func _AccelerateCar(power, delta):
	var frictionFactor = _AverageFriction(allWheels)
	
	var target_speed = power
	currentSpeed = lerp(currentSpeed, target_speed, ACCELERATION_RATE * delta * gearRatios[SimEngine.currentGear - 1])
	
	
	var force = (currentSpeed*frictionFactor) * delta * Vector2.UP
	force = force.rotated(rotation)
	
	
	#Calculate wheel slip from lack of traction
	var tractionFactor = _TransmitPower(force, allWheels, delta)
	
	#print(_calculate_drag_factor(_ForceToMPH(force)))
	
	force *= tractionFactor
	return force


##Handles Anguler Velocity (the rate at which the car turns), mainly slows the "spin" speed of the car
func _AngulerFriction(wheels, delta):
	var averageWheelAngle = 0
	var angularFriction = 0
	var wheelAngles = []
	
	for wheel in wheels:
		var globalAngle = wheel.global_rotation_degrees + 90
		wheelAngles.append(globalAngle)
	
	averageWheelAngle = CalculateAverageAngle(wheelAngles) + 180

	var velocityAngle = fmod((velocity.angle() * 180 / PI), 360.0)
	velocityAngle = velocityAngle + 360 if velocityAngle < 0 else velocityAngle
	
	var angleDifference = angle_difference(deg_to_rad(velocityAngle), deg_to_rad(averageWheelAngle))
	angleDifference = abs(rad_to_deg(angleDifference))
	
	if visualizeLines:
		VisualizeAngle(wheelLine, global_position, averageWheelAngle, 500)
		VisualizeAngle(velocityLine, global_position, velocityAngle, 500)
	
	var frictionMultiplier = clamp(pow(angleDifference / 90.0, 2), 0.0, 1.0) # Example of non-linear friction
	angularFriction = BASE_ANGULAR_FRICTION + (BASE_ANGULAR_FRICTION * frictionMultiplier)
	
	return angularFriction * sign(angularVelocity) * delta
	
	#print("Average Wheel Angle: ", averageWheelAngle, " Velocity Angle: ", velocityAngle, " Difference: ", angleDifference)

func CalculateAverageAngle(angles: Array):
	var average_x = 0.0
	var average_y = 0.0

	for angle in angles:
		angle = fmod(angle, 360.0)  # Normalize to 0-360 range
		var angle_radians = deg_to_rad(angle)
		average_x += cos(angle_radians)
		average_y += sin(angle_radians)

	average_x /= angles.size()
	average_y /= angles.size()

	var average_angle = rad_to_deg(atan2(average_y, average_x))
	return fmod(average_angle, 360.0)  # Return angle in 0-360 range 

func _TransmitPower(power: Vector2, wheels: Array, delta: float):
	var deltaV = (power - previousVelocity).length()
	var averageTraction = _AverageTraction(wheels)
	var velocityChange = 0
	var totalTraction = 0.0
	for wheel in wheels:
		var speedCapacity = wheel.CalculateSpeedCapacity(averageTraction)
		velocityChange = deltaV * wheel.powerBias
		#print(deltaV)
	
		if velocityChange > wheel.speedCapacity:
			#totalTraction += wheel.TransmitPower(velocityChange, delta)
			pass
		else:
			totalTraction += 1.0
			
	return totalTraction / 4.0

func _RotateBody(velocityMagnitude, delta): ##Rotates wheels towards user input, then rotates car body to match
	var targetRotationSpeed = clamp(velocityMagnitude, 0, MAX_ROTATION_SPEED)
	var turnAngle = clamp(userSteering * maxSteeringAngle, -maxSteeringAngle, maxSteeringAngle) #Where the wheels should be facing in relation to the users input
	var realAngle = _AdjustWheelRotation(frontWheels, turnAngle, delta) #Physical Angle of the wheels
	var tractionOffset = (_CalculateAngularAdjustment(allWheels)) #Calculate effect of wheels having differnt traction values
	
	var bodyAngle = rotation_degrees
	
	var angularFriction = _AngulerFriction(allWheels, delta)
		
	var steeringTorque = (userSteering * TORQUE_FACTOR * currentSpeed * delta) / momentOfIntertia #Calculate the car "carrying" its own momentum
	angularVelocity -= angularFriction - steeringTorque
	
	angularVelocity = clamp(angularVelocity, -MAX_TORQUE, MAX_TORQUE)
	print(angularVelocity)
	
	bodyAngle += angularVelocity
	
	#Introduce some form of drag factor
	
	bodyAngle = lerp(bodyAngle, realAngle + bodyAngle + tractionOffset, targetRotationSpeed * delta)
	bodyAngle = fmod(bodyAngle, 360.0)
	
	return bodyAngle
	
	
func _calculate_drag_factor(current_speed):
	var drag_coefficient = 0.5  # Adjust this for the strength of the drag 
	var max_drag_speed = 80.0     # Speed at which the drag effect becomes significant
	var drag_exponent = 2        # Controls how quickly drag increases (higher = steeper increase)
	
	var normalized_speed = clamp(current_speed / max_drag_speed, 0.0, 1.0)

	return (1.0 + (drag_coefficient * pow(normalized_speed, drag_exponent)))

func _AdjustWheelRotation(wheelNode: Node2D, target_angle: float, delta: float):
	var return_speed = 5.0
	var steer_amount
	var current_angle

	for i in wheelNode.get_children():
		current_angle = i.rotation_degrees
		#var difference = target_angle - current_angle  # No wrapf needed!
		
		# Return-to-center
		if abs(target_angle) < 0.1:
			var return_amount = clamp(abs(current_angle) * delta, -return_speed * delta, return_speed * delta)
			i.rotation_degrees -= return_amount

		# Smooth turning
		steer_amount = lerp(current_angle, target_angle, SMOOTH_FACTOR * delta)
		i.rotation_degrees = clamp(steer_amount, -maxSteeringAngle, maxSteeringAngle) 
	
	return steer_amount + current_angle
	
func _AverageTraction(wheels: Array):
	var totalTraction = 0.0
	for wheel in wheels:
		totalTraction += wheel.traction
		
	return (totalTraction / wheels.size())

func _AverageFriction(wheels: Array):
	var totalFriction = 0.0
	for wheel in wheels:
		totalFriction += wheel.friction
	
	return (totalFriction / wheels.size())

func _CalculateForceDirection(wheels: Array):
	var total_traction = 0.0
	var weighted_sum = Vector2.ZERO
	
	for wheel in wheels:
		if wheel.isDrivingWheel:
			total_traction += wheel.traction
			weighted_sum += wheel.position * wheel.traction

	if total_traction == 0.0:
		return Vector2.UP  # Default to UP if no traction

	return weighted_sum / total_traction

func _CalculateAngularAdjustment(wheels: Array):
	var tractionDifference = 0.0
	for wheel in wheels:
		if wheel.isDrivingWheel:
			# Assuming right wheels are on the positive X side
			tractionDifference += wheel.traction * wheel.position.x
			
			return tractionDifference * ANGULAR_INFLUENCE

func _Differental(wheels: Array, delta): ##Simulate locking the wheels together, normalize towards average traction
	var differentialStep = 0.05 * delta
	var averageTraction = _AverageTraction(wheels)
	for wheel in wheels:
		if wheel.traction - averageTraction > 0 - differentialStep:
			wheel.traction -= differentialStep
		elif wheel.traction - averageTraction < 0 + differentialStep:
			wheel.traction += differentialStep
		

func handle_user_input():
	#Handle Steering Related Inputs
	if Input.is_action_pressed("left"):
		userSteering = -1.0
	elif Input.is_action_pressed("right"):
		userSteering = 1.0
	else:
		userSteering = 0.0
	
	#Handle Acceleration Related Inputs
	if Input.is_action_pressed("acceleration"):
		userThrottle = 1.0
	else:
		userThrottle = 0.0
	
	#Handle Gear Changes
	var currentGear = SimEngine.currentGear
	if Input.is_action_just_pressed("shiftup") and (currentGear + 1 <= gearRatios.size()):
			SimEngine.ShiftGear(currentGear + 1)
	elif Input.is_action_just_pressed("shiftdown") and currentGear > 1:
		SimEngine.ShiftGear(currentGear - 1)

