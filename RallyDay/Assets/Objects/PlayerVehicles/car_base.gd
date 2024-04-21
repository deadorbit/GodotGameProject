extends CharacterBody2D

const ROTATION_SENSITIVITY: float = 1.0 #How fast body should turn towards wheels
const MAX_ROTATION_SPEED: float = 15.0  #Maximum rate at which body can turn towards wheel angle
const SMOOTH_FACTOR: float = 1.2 #How fast wheels turn towards the target angle
const ANGULAR_INFLUENCE = 1 #How much differences in traction can "turn" the car
const FRICTION_COEFFICENT = 1
const MAX_TORQUE = 2.0 ## Hard limit on the maximal rotational velocity that can be achieved
const BASE_ANGULAR_FRICTION = 5 ## decrease in rotational velocity over over
const MINIMUM_FRICTION = 25 ##Minimum gaurenteed loss in speed
const driftLimit = 20 ## Degrees in which vehicle is considered sliding (or drifting)

#Constants related to drag (Limits rotation speed based on 
const DRAG_FACTOR = 2  # Multiplyer to drag effect
const DRAG_LIMIT = 120.0  #Speed (in MPH) where drag kicks in 
const DRAG_EXPONENT = 2 #Effects how sharply drag kicks in as car passes DRAG_LIMIT

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
@export var reverseGear: float
@export var breakEfficency: float

var Menu

@onready var frontWheels: Node2D = $FrontWheels
@onready var rearWheels: Node2D = $RearWheels
@onready var breakLightLights: Node2D = $TailLightPoints
#@onready var UI: PackedScene = preload("res://Interface.tscn")
@onready var DebugUI: PackedScene = preload("res://Assets/Scenes/UI/DebugInterface.tscn")
@onready var root = get_node("/root")

var userSteering = 0.0  # Stores user input (-1 to 1)
var SimEngine: EngineNode
var userThrottle: float = 0.0
var speed: float = 0.0
var averageFriction: int = 0
var previousVelocity = Vector2.UP
var previousRotation = 0
var previous2ndRotation = 0
var allWheels: Array
var angulerVelocityQueue: Array
var previousTime = Time.get_unix_time_from_system()
var previousPosition = Vector2(0,0)
var inverseVelocity = Vector2(0,0)
var previousSpeed: float = 0.0
var sliding = false

var speedFactor: float = 0.0
var accelerationFactor: float = 0.0
var decelerationFactor: float = 0.0

#Variables to control speed interpolation
var currentSpeed = 0.0

#Controls turning momentum
var angularVelocity = 0.0
var momentOfIntertia = 175000
var previousAngularVelocity = 0.0

#Debug
var visualizeLines: bool = true
var debugMode: bool = true
@onready var debug = $Debug
var velocityLine: Line2D
var wheelLine: Line2D
var turningLine: Line2D
var headingLine: Line2D

func _ready():
	#Create Engine Object based off car object data
	SimEngine = EngineNode.new(gearRatios, RPMLimit, RPMCurve, enginePower, breakEfficency, reverseGear)
	Globals.playerEngine = SimEngine
	
	#position = get_viewport_rect().get_center()
	
	allWheels = frontWheels.get_children() + rearWheels.get_children()
	
	#Create car menu
	Menu = DebugUI.instantiate()
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
	
	#Update constants
	speedFactor = Globals.SPEED_FACTOR
	accelerationFactor = Globals.ACCELERATION_RATE
	decelerationFactor = Globals.DECELERATION_RATE

func _physics_process(delta):
	handle_user_input()
	
	var wheelFriction = _AverageFriction(allWheels)
	var power = SimEngine.EngineLogic(userThrottle,wheelFriction, delta) * speedFactor
	
	Globals.playerDelta = delta
	Globals.playerWheels = allWheels
	Globals.playerEngineChange.emit()
	
	if(userThrottle < 0.0):
		_Breaking(allWheels, abs(userThrottle), delta)
	else:
		_Breaking(allWheels, 0.0, delta)
	
	var newVelocity = _AccelerateCar(power, delta)
	velocity = newVelocity
	previousVelocity = newVelocity
	Globals.playerPreviousSpeed = velocity

	var newRotation = _RotateBody(delta)
	previousRotation = rotation
	rotation_degrees = newRotation
	previousPosition = position
	move_and_slide()
	
	Globals.playerSpeed = velocity
	
	#handle collisions
	var collision = get_last_slide_collision()
	if collision != null:
		_CollisionHandling(collision)
	
	#_Differential(allWheels, velocityMagnitude, delta)
	_RollWheels(allWheels, delta)#Calculate wheel effects

func _Breaking(allWheels: Array, breakAmount: float, delta: float):
	for wheel in allWheels:
		wheel.breakingFriction = breakAmount * breakEfficency

func VisualizeAngle(line: Line2D, start_point: Vector2, angle: float, length):
	var end_point = start_point + Vector2(length, 0).rotated(deg_to_rad(angle))
	line.points = [start_point, end_point]  # Update Line2D points
	
func ToggleBreakLights(breakLights: Node2D, state: bool):
	for light in breakLights.get_children():
		light.enabled = state

##Function which handles calculating velocity changes
func _AccelerateCar(power, delta):
	var frictionFactor = _AverageFriction(allWheels)
	#var tractionFactor = _AverageTraction(allWheels)
	var tractionFactor = Globals.CalculateTractionFactor(velocity, Globals.playerTopSpeed)
	#print("TRACTION FACTOR: ", tractionFactor)
	
	var targetSpeed = power * (1.0 - frictionFactor)
	var momentumRate = 1.0
	
	#print("TARGET SPEED: ", target_speed)
	
	if targetSpeed - currentSpeed >= -10.0: #Car is acclerating (some margin for error)
		var accelerationTractionModifier = Globals.CalculateAccelerationRate(tractionFactor)
		momentumRate = accelerationTractionModifier * accelerationFactor * delta
		currentSpeed = lerp(currentSpeed, targetSpeed, momentumRate)
	else:
		momentumRate = decelerationFactor * delta
		currentSpeed = lerp(currentSpeed, targetSpeed, momentumRate)
	
	Globals.playerMomentum = momentumRate
	currentSpeed -= MINIMUM_FRICTION
	if currentSpeed < 0.0:
		currentSpeed = 0.0
	
	var currentVelocity: Vector2 = ((currentSpeed) * Vector2.UP * delta)
	
	#var force = (currentSpeed*frictionFactor) * delta * Vector2.UP
	
	#Calculate wheel slip from lack of traction
	#var tractionSlip = _TransmitPower(currentVelocity, allWheels, delta)
	
	var slipTractionModifier = Globals.CalculatePositionRate(tractionFactor)
	#print("SLIP TRACTION MOD: ", slipTractionModifier)
	
	currentVelocity = (currentVelocity).rotated(rotation)
	
	var slipAmount = (rad_to_deg(currentVelocity.angle_to(previousVelocity)))
	var slideAmount = (rad_to_deg(previousPosition.angle_to(position)))
	#print("SLIP ANGLE: ", slipAngle, " SLIDE ANGLE: ", slideAngle)
	if abs(slideAmount) > driftLimit or abs(slipAmount) > driftLimit: #Car is sliding
		var slideDistance = position.distance_to(previousPosition)/ delta
		sliding = true
		print("Slidey: ", slideDistance)
		print("Drifty: ", slipAmount)
		#pass 
	
	currentVelocity = (previousVelocity - inverseVelocity).lerp(currentVelocity, slipTractionModifier)
	
	var inverseVelocityVector = inverseVelocity
	var bounceFactor = 1.0
	
	currentVelocity += inverseVelocityVector
	#Car Recoil Direction
	
	if(visualizeLines):
		var tempLine = Line2D.new()
		tempLine.width = 2.5 / inverseVelocity.length()
		tempLine.points = [position, position + inverseVelocityVector]
		tempLine.z_index = 10
		tempLine.default_color = Color.YELLOW
		root.get_node("CarTestPlace").add_child(tempLine)
	
	Globals.playerInverseVelocity = inverseVelocity
	inverseVelocity = inverseVelocity.lerp(Vector2(0,0), bounceFactor * delta)
	if inverseVelocity.length() < 5.0:
		inverseVelocity = Vector2(0,0)
	
	previousSpeed = targetSpeed
	
	return currentVelocity

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
	#print("DELTA V: ", deltaV)
	
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

func _RotateBody(delta): ##Rotates wheels towards user input, then rotates car body to match
	##!!! MAKE SURE TO DOUBLE CHECK ALL ANGLES ARE NORMALIZED
	var playerSpeed = Globals.SpeedToMPH(velocity)
	var currentAngle = rotation_degrees
	var dragFactor = _CalculateDragFactor(playerSpeed, delta)
	
	#Gross angle calcutions, angle car should work towards
	var turnAngle = clamp(userSteering * maxSteeringAngle, -maxSteeringAngle, maxSteeringAngle) #Where the wheels should be facing in relation to the users input
	var realAngle = _AdjustWheelRotation(frontWheels, turnAngle, delta) #Physical Angle of the wheels
	var tractionOffset = _CalculateAngularAdjustment(allWheels) #Calculate effect of wheels having differnt traction values
	var grossAngle = fmod(currentAngle + realAngle + tractionOffset, 360.0)
	#print("TRACTION OFFSET: ", tractionOffset)
	#print("REAL ANGLE: ", realAngle)
	
	#var angularFriction = _AngulerFriction(allWheels, grossAngle, delta)
	var averageFriction = _AverageFriction(allWheels)
	var angularVelocity = _CalculateAngularVelocity(previousAngularVelocity, dragFactor, userSteering,realAngle,averageFriction, delta)
	previousAngularVelocity = angularVelocity
	
	#Introduce some form of drag factor
	if sliding:
		angularVelocity *= 0.5
	
	var netAngle = lerp(currentAngle, grossAngle, angularVelocity)
	var deltaAngle = netAngle - currentAngle #Change in rotation
	
	#Calculate friction for wheels
	var rotationForce = _CalculateRotationForce(deltaAngle, angularVelocity)
	#print("ROTATIONAL FORCE: ", abs(rotationForce))
	
	var turning_slowdown_factor = 25
	var slowdown_from_turning = abs(turning_slowdown_factor * rotationForce)
	
	
	if(currentSpeed == 0): #Avoid 0 divisor
		currentSpeed = 1.0

	#_ApplyWheelFriction(allWheels, slowdown_from_turning, delta)
	
	
	
	if abs(deltaAngle) < 0.1: #Ignore excesivly small adjustments
		return rotation_degrees
	
	
	return netAngle

func _CalculateAngularVelocity(previousAngularVelocity: float, dragFactor: float,userSteering: float,realAngle: float,averageFriction: float, delta: float) -> float:
	var momentOfInteria = 80 #In MPH
	var currentSpeed = Globals.SpeedToMPH(velocity)
	var speedFactor = clamp(currentSpeed / momentOfInteria, 0.0, 1.0)
	#print("SPEED FACTOR:", speedFactor)
	var rotationSpeedFactor = sin((PI/2)*(speedFactor**0.5))
	var rotationSpeed = rotationSpeedFactor* ROTATION_SENSITIVITY * delta  # Or tweak the exponent 
	#print(currentSpeed)
	return rotationSpeed
	
	#print(rotationChange)
	#
	#var speedFactor = clamp((currentSpeed / momentOfIntertia), 0.0, 1.0)
	#var torqueFactor = remap(speedFactor,0.0,1.0,0.5,1.0) if speedFactor > 0 else 0
	#var effectiveMaxTorque = MAX_TORQUE * int(speedFactor > 0)#* torqueFactor * rotationSharpness * userSteering
	#var rotationSharpness = abs(realAngle/(maxSteeringAngle*2))
	
	#if speedFactor == 0.0:
	#	return 0.0
	
	#var angularLoss = BASE_ANGULAR_FRICTION * clamp(speedFactor, 0.05, 1.0)**0.5 #*dragFactor #* angularNormization
	#var angularGain = BASE_ANGULAR_GAIN * clamp(speedFactor, 0.05, 1.0)**0.5
	#print("EFFECTIVE MAX TORQUE: ",effectiveMaxTorque," ANGULAR FRICTION: ", angularLoss, " ANGULAR GAIN: ", angularGain)
	#
	#angularVelocity = previousAngularVelocity - angularLoss
	#angularVelocity += angularGain
	#
	#if angularVelocity < 0:
		#angularVelocity = 0.0
	#if angularVelocity > effectiveMaxTorque:
		#angularVelocity = (angularVelocity/2.0)
	#
	#angularVelocity = lerp(previousAngularVelocity, angularVelocity, rate * delta)
	
	#return min(effectiveMaxTorque, MAX_TORQUE)
	
func _CalculateRotationForce(angleChange: float, angularVelocity: float) -> float: #Return turning force as an integer calculated by speed and angle change
	return angleChange * pow(1.0+angularVelocity,2)
	
func _RollWheels(wheels: Array, delta): #Miscinaious calculations for wheels
	for wheel in wheels:
		wheel.RollWheel(delta)
	
func _CalculateDragFactor(currentSpeed, delta): ##TODO: Modify drag to start at drag_limit and exponentially increase
	var normalized_speed = clamp(currentSpeed / DRAG_LIMIT, 0.0, 1.0)  
	var drag = DRAG_FACTOR * pow(normalized_speed, DRAG_EXPONENT)
	return (1/(1.0 + drag)) * delta # Ensures there's always some baseline drag

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
	var totalTraction = 0.0
	var weightedPositionSum = 0.0
	#var numWheels = wheels.size()
	
	for wheel in wheels:
		totalTraction += wheel.traction
		weightedPositionSum += wheel.traction * wheel.position.x 
	
	var normalizedPositionSum = weightedPositionSum / totalTraction   
	
	return normalizedPositionSum * ANGULAR_INFLUENCE 

#func _Differential(wheels: Array, speed: int, delta): 
	#var differentialPower = 0.01
	#var differentialStep = clamp(differentialPower * speed * delta, 0,differentialPower * delta)
	##print("DIFFERENTIAL STEP: ", differentialStep)
	#var averageTraction = _AverageTraction(wheels)
	#
	#for wheel in wheels:
		#var difference = wheel.traction - averageTraction 
#
		##  Adjust towards the average 
		#if abs(difference) > differentialStep:  # Check if outside the threshold
			#if difference > 0: 
				#wheel.traction -= differentialStep
			#else:  # difference < 0
				#wheel.traction += differentialStep
		#elif abs(difference) <= differentialStep:
			#wheel.traction = averageTraction  # Snap to average if very close
		##print(wheel.traction)

func _ApplyWheelFriction(wheels: Array, frictionForce: float, _delta: float):
	print("TURNING FRICTION: ", frictionForce)
	for wheel in wheels:
		wheel.turningFriction = frictionForce

func handle_user_input():
	#Handle Steering Related Inputs
	if Input.is_action_pressed("left"):
		userSteering = -1.0
	elif Input.is_action_pressed("right"):
		userSteering = 1.0
	else:
		userSteering = 0.0
	
	#Handle Acceleration Related Inputs
	ToggleBreakLights(breakLightLights, false)
	if Input.is_action_pressed("acceleration"):
		userThrottle = 1.0
	elif Input.is_action_pressed("break"):
		userThrottle = -1.0
		ToggleBreakLights(breakLightLights, true)
	else:
		userThrottle = 0.0
	
	#Handle Gear Changes
	var currentGear = SimEngine.currentGear
	if Input.is_action_just_pressed("shiftup") and (currentGear + 1 <= gearRatios.size()):
			SimEngine.ShiftGear(currentGear + 1)
	elif Input.is_action_just_pressed("shiftdown") and currentGear > 1:
		SimEngine.ShiftGear(currentGear - 1)

func _CollisionHandling(collisionData: KinematicCollision2D):
	var carForwardDirection = (Vector2.UP.rotated(rotation)).normalized()
	var tempLine
	
	#tempLine = Line2D.new()
	#tempLine.width = 5
	#tempLine.points = [position, position * carForwardDirection * 50]
	#tempLine.z_index = 10
	#tempLine.default_color = Color.RED
	#root.get_node("CarTestPlace").add_child(tempLine)
	
	var collisionNormal = collisionData.get_normal()
	var collisionVelocity = velocity
	#print(velocity)
	#var collisionAngle = collisionData.get_angle(carForwardDirection)
	#var collisionAngle  = carForwardDirection.dot(collisionNormal.normalized())
	
	var recoilMagnitude = collisionVelocity.length()
	#print("VElocity: ", collisionVelocity.length())
	#var angleFactor = abs(cos(collisionAngle)) # Factor between 0 and 1
	var collisionAngle = carForwardDirection.dot(collisionNormal.normalized())
	var angleFactor = abs(cos(PI/2 - collisionAngle))
	var angleReduction = (1-angleFactor)
	#print("Angle Factor: ", angleFactor)

	var adjustedRecoilMagnitude = recoilMagnitude * angleFactor
	
	if (adjustedRecoilMagnitude <= 100.0):
		return #Ignore tiny collisions
	#
	## Calculate recoil direction based on collision normal and car's orientation
	var recoilDirection = -(carForwardDirection.reflect(collisionNormal))
	#print("RECOIL DIR: ", recoilDirection)
	#
	var recoil = (recoilDirection * adjustedRecoilMagnitude)
	##print("RECOIL MAG: ", recoil.length())
	
	
	if(visualizeLines):
		
		##Car forward velocity
		tempLine = Line2D.new()
		tempLine.width = 5
		tempLine.points = [position, position + carForwardDirection * 500]
		tempLine.z_index = 10
		tempLine.default_color = Color.RED
		root.get_node("CarTestPlace").add_child(tempLine)
		
		#Car Recoil Direction
		tempLine = Line2D.new()
		tempLine.width = 5
		tempLine.points = [position, position + recoil]
		tempLine.z_index = 10
		tempLine.default_color = Color.GREEN
		root.get_node("CarTestPlace").add_child(tempLine)
	
	#Avoid lighter taps overrighting larger collisions, ignore excesivly large recoils
	if recoil.length() > inverseVelocity.length() and recoil.length() < 10000:
		inverseVelocity = recoil
		currentSpeed *= angleReduction 
		SimEngine.currentRPM *= angleReduction
	#print("RECOIL: ", recoil)
	
	print("ANGLE: ", collisionAngle, " VELOCITY: ", collisionVelocity)

