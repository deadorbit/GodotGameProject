extends CharacterBody2D

const ROTATION_SENSITIVITY: float = 0.05 #How fast body should turn towards wheels
const MAX_ROTATION_SPEED: float = 15.0  #Maximum rate at which body can turn towards wheel angle
const SMOOTH_FACTOR: float = 1.2 #How fast wheels turn towards the target angle
const ANGULAR_INFLUENCE = 1 #How much differences in traction can "turn" the car
const ACCELERATION_RATE = 0.25  # Adjust this for how quickly the car accelerates
const FRICTION_COEFFICENT = 1
const SPEED_FACTOR = 50 ## Adjust this to change raw power values of engine
const MAX_TORQUE = 5.0 ## Hard limit on the maximal rotational velocity that can be achieved
const TORQUE_FACTOR = 0.01 ## Changes effectviness of rotating the body effectivly how fast the body matches the wheels
const BASE_ANGULAR_FRICTION = 5 ## decrease in rotational velocity over over
const MIN_TORQUE = 0.001 ##Minimum force to continue rotating

@export var turn_speed: int ## Maximum turn speed of car wheels towards user input
@export var maxSteeringAngle: int
@export var RPMCurve: Curve
@export var gearRatios: Array
@export var RPMLimit: int
@export var enginePower: float
@export var bodyWeight: int = 100
@export var maxSpeed: int
@export var RPMGauge: CompressedTexture2D
@export var RPMNeedle: CompressedTexture2D
@export var RPMLight: CompressedTexture2D
@export var SpeedometerGauge: CompressedTexture2D
@export var SpeedometerNeedle: CompressedTexture2D
@export var SpeedometerElectronic: CompressedTexture2D
@export var maxRPMGaugeAngle: float
@export var maxSpeedometerAngle: float
@export var maxSpeedometerSpeed: float ## Maximum numerical value at the end of the spedometer

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
var angulerVelocityQueue: Array
var previousTime = Time.get_unix_time_from_system()
var previousPosition = Vector2(0,0)

#Variables to create arbitary speed value
var currentSpeed = 0.0

#Controls turning momentum
var angularVelocity = 0.0
var momentOfIntertia

#Debug
var visualizeLines: bool = true
@onready var debug = $Debug
var velocityLine: Line2D
var wheelLine: Line2D
var turningLine: Line2D

func _ready():
	#Create Engine Object based off car object data
	SimEngine = EngineNode.new(gearRatios, RPMLimit, RPMCurve, enginePower)
	Globals.playerEngine = SimEngine
	
	#print(bodyWeight)
	momentOfIntertia = bodyWeight * 12 # Resistance of car to turning
	position = get_viewport_rect().get_center()
	
	allWheels = frontWheels.get_children() + rearWheels.get_children()
	
	#Create car menu
	Menu = UI.instantiate()
	root.add_child.call_deferred(Menu)
	
	Globals.playerMaxRPMGaugeAngle = maxRPMGaugeAngle
	Globals.playerMaxSpeedometerAngle = maxRPMGaugeAngle
	Globals.playerMaxSpeedometerSpeed = maxSpeedometerSpeed
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
		turningLine = debug.get_node("TurningAngle").duplicate()
		debugNode.add_child(turningLine)
	
	#frontWheels.get_node("LeftWheel").traction = 0.1

func _physics_process(delta):
	handle_user_input()
	#print(position)
	
	Globals.playerDelta = delta
	Globals.playerWheels = allWheels
	Globals.playerEngineChange.emit()
	var power = SimEngine.EngineLogic(userThrottle, delta) * SPEED_FACTOR
	var force = _AccelerateCar(power, delta)
	#print(force)
	
	velocity = force
	previousVelocity = force
	
	var velocityMagnitude = velocity.length()
	Globals.playerSpeed = int((velocityMagnitude/20))

	rotation_degrees = _RotateBody((velocityMagnitude * ROTATION_SENSITIVITY) / SPEED_FACTOR, delta)
	previousPosition = global_position
	move_and_slide()
	_Differential(allWheels, velocityMagnitude, delta)
	_RollWheels(allWheels, delta)

func _CalculateInverseForces(): #Calculate forces that would slow down the car (Friction/Drag/ect.)
	pass

func VisualizeAngle(line: Line2D, start_point: Vector2, angle: float, length):
	var end_point = start_point + Vector2(length, 0).rotated(deg_to_rad(angle))
	line.points = [start_point, end_point]  # Update Line2D points
	

func _ForceToMPH(forceValue):
	return forceValue.length() / 20

##Function which handles calculating velocity changes
func _AccelerateCar(power, delta):
	#var frictionFactor = _AverageFriction(allWheels)
	
	var target_speed = power
	currentSpeed = lerp(currentSpeed, target_speed, ACCELERATION_RATE * delta * gearRatios[SimEngine.currentGear - 1])
	
	var force = currentSpeed * Vector2.UP * delta
	
	#var force = (currentSpeed*frictionFactor) * delta * Vector2.UP
	
	
	#Calculate wheel slip from lack of traction
	var tractionSlip = _TransmitPower(force, allWheels, delta)
	var averageTraction = _AverageTraction(allWheels)
	#averageTraction = 1
	
	force *= averageTraction
	force = (force + tractionSlip).rotated(rotation)
	return force


##Handles Anguler Velocity (the rate at which the car turns), mainly slows the "spin" speed of the car/ returns to normal angle
func _AngulerFriction(wheels: Array, rotationalAngle: float, delta: float):
	var averageWheelAngle = 0
	var angularFriction = 0
	var wheelAngles = []
	
	for wheel in wheels:
		var globalAngle = wheel.global_rotation_degrees + 90
		wheelAngles.append(globalAngle)
	
	averageWheelAngle = CalculateAverageAngle(wheelAngles) + 180
	
	#var movement_direction = (global_position - previousPosition).normalized()  # Direction of movement
	#var carMovementAngle = global_position.angle_to(previousPosition) * 180 / PI  # Angle relative to the X-axis
	var movement_direction = (global_position - previousPosition)  # Direction of movement
	var carMovementAngle = movement_direction.angle() * 180 / PI
	carMovementAngle = carMovementAngle + 360 if carMovementAngle < 0 else carMovementAngle
	#print(carMovementAngle / delta)
	
	
	var angleDifference = angle_difference(deg_to_rad(rotationalAngle), deg_to_rad(averageWheelAngle))
	angleDifference = abs(rad_to_deg(angleDifference))
	#print(velocityAngle)
	
	if visualizeLines:
		VisualizeAngle(wheelLine, global_position, averageWheelAngle, 500)
		#VisualizeAngle(velocityLine, global_position, carMovementAngle, 500)
	
	var frictionMultiplier = clamp(pow(angleDifference / 90.0, 2), 0.0, 1.0) # Example of non-linear friction
	angularFriction = BASE_ANGULAR_FRICTION + (BASE_ANGULAR_FRICTION * frictionMultiplier)
	
	
	#print("Average Wheel Angle: ", averageWheelAngle, " Velocity Angle: ", velocityAngle, " Difference: ", angleDifference)
	return angularFriction * sign(angularVelocity) * delta
	

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


##Checks if wheel force > slip threshold, if so converts force to traction and caues slip
func _TransmitPower(power: Vector2, wheels: Array, delta: float) -> Vector2:
	var deltaV = power.length() - previousVelocity.length() #Change in velocity (acceleration)
	deltaV *= delta
	print("DELTA V: ", deltaV)
	
	var rotationForce = 0
	var slip: Vector2 = Vector2(0,0)
	for wheel in wheels:
		var speedCapacity = wheel.CalculateSpeedCapacity()
		rotationForce = (1.0 + deltaV) * wheel.powerBias #all wheels have power bias, even non-driving wheels to simulate them rolling
		#print("WHEEL TORQUE: ", rotationForce, " SPEED CAPACITY: ", speedCapacity)
	
		if rotationForce > speedCapacity:
			#Simulate wheel slip
			slip += wheel.TransmitPower(rotationForce, delta)
		else:
			wheel.TransmitPower(rotationForce, delta)
	
	return slip

func _CalculateForwardVelocity() -> float:
	var normalizedV = velocity.normalized()
	var carDirection = Vector2(cos(rotation), sin(rotation)).rotated(deg_to_rad(-90))
	var forwardV = normalizedV.dot(carDirection) * velocity.length() # Get magnitude of original velocity
	#print("FORWARD VELOCITY: ", forwardV)
	
	return forwardV
	

#func _AngulurVelocityQueue(newValue):
	#var queue = angulerVelocityQueue
	#var queueSize = queue.size()
	#if queueSize >= 30:
		#queue.pop_front()
		#queue.push_back(newValue)
	#else:
		#queue.push_back(newValue)
	#
	#var avgValue = 0.0
	#for element in queue:
		#avgValue += element
	#print(avgValue)

func _RotateBody(velocityMagnitude, delta): ##Rotates wheels towards user input, then rotates car body to match
	##!!! MAKE SURE TO DOUBLE CHECK ALL ANGLES ARE NORMALIZED
	var targetRotationSpeed = clamp(velocityMagnitude, 0, MAX_ROTATION_SPEED)
	var turnAngle = clamp(userSteering * maxSteeringAngle, -maxSteeringAngle, maxSteeringAngle) #Where the wheels should be facing in relation to the users input
	var realAngle = _AdjustWheelRotation(frontWheels, turnAngle, delta) #Physical Angle of the wheels
	#print("REAL ANGLE: ", realAngle)
	var tractionOffset = (_CalculateAngularAdjustment(allWheels, velocityMagnitude)) #Calculate effect of wheels having differnt traction values
	print("TRACTION OFFSET: ", tractionOffset)
	
	var currentAngle = rotation_degrees
	var futureAngle = fmod(currentAngle + realAngle + tractionOffset, 360.0)
	
	var angularFriction = _AngulerFriction(allWheels, futureAngle, delta)
	#print("ANGULAR FRICTION: ", angularFriction)
	var dragFactor = _CalculateDragFactor(Globals.playerSpeed)
	
	
	var steeringTorque = (userSteering * TORQUE_FACTOR * currentSpeed * delta) / momentOfIntertia #Calculate the car "carrying" its own momentum
	#print("STEERING TORQUE: ", steeringTorque)
	
	
	steeringTorque = steeringTorque * (1 / dragFactor) #Simulate the cars steering becoming unresponsive at high speeds
	#print("Effective Torque: ", steeringTorque)
	
	var maximumTorque = MAX_TORQUE * (1/ dragFactor) #Prevent car from infinitly gaining speed
	#print("DRAG FACTOR: ", dragFactor)
	#print("Maximum Torque: ", maximumTorque)
	
	#print("ANGULAR VELCOITY: ",angularVelocity)
	angularVelocity -= angularFriction - steeringTorque
	
	angularVelocity = clamp(angularVelocity, -maximumTorque, maximumTorque) #Maximum limit on cars turning ability
	
	targetRotationSpeed *= (1/dragFactor) * delta
	
	futureAngle += angularVelocity
	#_AngulurVelocityQueue(angularVelocity)
	
	#Introduce some form of drag factor
	futureAngle = lerp(currentAngle, futureAngle, targetRotationSpeed)
	futureAngle = fmod(futureAngle, 360.0)
	
	#Calculate friction for wheels
	var deltaAngle = futureAngle - rotation_degrees
	var rotationForce = deltaAngle * pow(1.0+angularVelocity,2)
	#print("ROTATIONAL FORCE: ", abs(rotationForce))
	
	if visualizeLines:
		VisualizeAngle(turningLine, global_position, rotation_degrees - 90, abs(rotationForce) * 500) #Displays cars turn amount and force
	
	#Manually cancel out tiny changes in rotation
	if abs(deltaAngle) < 0.1:
		return rotation_degrees
	
	return futureAngle
	
func _RollWheels(wheels: Array, delta): #Miscinaious calculations for wheels
	for wheel in wheels:
		wheel.RollWheel(delta)
	
func _CalculateDragFactor(currentSpeed):
	var drag_coefficient = 2  # Adjust for desired drag strength 
	var max_drag_speed = 120.0   
	var drag_exponent = 2
	#print("SPEED: ", currentSpeed)
	
	var normalized_speed = clamp(currentSpeed / max_drag_speed, 0.0, 1.0)  
	var drag = drag_coefficient * pow(normalized_speed, drag_exponent)
	return 1.0 + drag # Ensures there's always some baseline drag

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

func _CalculateAngularAdjustment(wheels: Array, speed: float):
	var tractionDifference = 0.0
	var totalTraction = 0.0
	var weightedPositionSum = 0.0
	#var numWheels = wheels.size()
	
	for wheel in wheels:
		totalTraction += wheel.traction
		weightedPositionSum += wheel.traction * wheel.position.x 
	
	var normalizedPositionSum = weightedPositionSum / totalTraction   
	
	return normalizedPositionSum * ANGULAR_INFLUENCE 

func _Differential(wheels: Array, speed: int, delta): 
	var differentialPower = 0.01
	var differentialStep = clamp(differentialPower * speed * delta, 0,differentialPower * delta)
	#print("DIFFERENTIAL STEP: ", differentialStep)
	var averageTraction = _AverageTraction(wheels)
	
	for wheel in wheels:
		var difference = wheel.traction - averageTraction 

		#  Adjust towards the average 
		if abs(difference) > differentialStep:  # Check if outside the threshold
			if difference > 0: 
				wheel.traction -= differentialStep
			else:  # difference < 0
				wheel.traction += differentialStep
		elif abs(difference) <= differentialStep:
			wheel.traction = averageTraction  # Snap to average if very close
		#print(wheel.traction)
		

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

