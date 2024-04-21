extends Node
signal playerEngineChange()

const SPEED_FACTOR = 20 ## Adjust this to change raw power values of engine
const MPH_CONVERSION_FACTOR = 0.75 ##Factor used to convert velocity units to MPH
const ACCELERATION_RATE = 0.75 ##Factor for default positive speed interpolation, Effectivly how long it takes to speed up
const DECELERATION_RATE = 0.25 ## Factor for default negative speed interpolation, Effectivly how long it takes to slow down

var playerEngine: EngineNode
var playerSpeed: Vector2 = Vector2(0,0)
var playerPreviousSpeed: Vector2 = Vector2(0,0)
var playerDelta: float = 0.01
var playerMaxRPMGaugeAngle: float = 0
var playerMaxSpeedometerAngle: float = 0
var playerMaxSpeedometerSpeed: float = 0.0
var playerWheels: Array = []
var playerTopSpeed: float = 200.0

#Values for debugging
var playerMomentum: float = 0.0
var playerInverseVelocity: Vector2 = Vector2(0,0)

func CalculateTractionFactor(speed: Vector2, topSpeed: float):
	return clamp(SpeedToMPH(speed)/topSpeed, 0.0, 1.0)
	
func SpeedToMPH(speed: Vector2):
	return (speed.length()/SPEED_FACTOR) * MPH_CONVERSION_FACTOR
	
#Calculates the accleraition rate (where 0 means no increase in speed, and 1 means the vehicle will perfectly map to the increased speed)
#From a traction value between 0-1
func CalculateAccelerationRate(traction: float):
	#Uses exponential Sin function, rapid growth towards 0.5, slower decay towards 1
	#peaks at PI (0.5) and tapers off towrads 1 (accleration beocmes less effective with speed)
	return clamp(sin((traction**0.5) * PI) * 1.1 + 0.1,0.0,1.0)
	
#Calculates interpolation rate of cars position to desired position, effectivly controls "driftyness" where near 0 values feels closer to ice
func CalculatePositionRate(traction):
	#U curve, exact movement at low and highspeeds, gives "arcade" feeling
	return clamp(1.0 - sin((traction**0.75) * (PI/1.2))+0.1,0.0,0.8)
