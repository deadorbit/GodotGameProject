class_name EngineNode extends Node2D

const powerLossFactor: float = 1.0 ## Magic number to modify RPM loss from friction
const torqueCurve: Curve = preload("res://Assets/Engines/TorqueCurve.tres")
const TIRE_FRICTION_FACTOR = 1 ##Multiplyer to increase friction this percent times tire friction

const ENGINE_UNITS = 100 #represents speed in pixels per frame
const FRICTION_UNITS = 50 #Represents base speed reduction in pixels per frame

var currentRPM: float = 0#not actally RPM, more equivliant to an arbitary "power" value
var gear_ratios = [3.454, 1.947, 1.336, 0.972, 0.738]
var clutch_engaged: bool = false 
var currentGear: int = 1

var reverse: bool = false
var reverseGearRatio: float = 0.35

var breakEfficiency: float = 1.0

var enginePowerFactor: float
var gearRatios: Array
var revLimit: int
var idleRPM: int
var clutch_time: float
var powerCurve: Curve
var clutch_timer: float
var gearCount: int
var prevRev: float
var physicsTick: int

func _OscillatingEngineModifier(time, frequency=1.0, amplitude=0.2):
	return (sin(time * frequency * 2.0 * PI) + 1.0) / 2.0 * amplitude


func _init(gearRatiosValue: Array, revLimitValue: int, powerCurveVaue: Curve, enginePowerFactorValue: float, breakEfficiencyValue: float, reverseGearRatioValue: float):
	self.gearRatios = gearRatiosValue
	self.revLimit = revLimitValue
	
	self.gearCount = gearRatios.size()
	self.currentGear = 1
	self.powerCurve = powerCurveVaue
	self.clutch_timer = 0.5
	self.enginePowerFactor = enginePowerFactorValue
	self.breakEfficiency = breakEfficiencyValue
	self.reverseGearRatio = reverseGearRatioValue

func _EngineReverse():
	return currentRPM

func EngineLogic(throttleInput, wheelFriction, delta):
	if(reverse == true):
		currentRPM = _EngineReverse()
		return currentRPM
	
	physicsTick = Engine.get_physics_frames()
	var tireFriction = max(TIRE_FRICTION_FACTOR * (TIRE_FRICTION_FACTOR * (wheelFriction)), 1)
	var friction = 1.0
	var breakForce = 1.0
	#print("TIRE FRICTION: ", tireFriction)
	var gearRatio = gearRatios[currentGear-1]
	var gearRPMLimit = revLimit / gearRatios[currentGear-1]

	var powerEffiency = max(powerCurve.sample(currentRPM/revLimit),0)
	var oscilationFactor = (1 - _OscillatingEngineModifier(physicsTick,0.2,0.2))
	#print(oscilationFactor)
	var enginePower = 0
	
	#print(throttleInput)
	if throttleInput >= 0.0: #Breaking
		enginePower = ENGINE_UNITS * powerEffiency * delta * throttleInput * (gearRatio**2) * enginePowerFactor * oscilationFactor * tireFriction
	else:
		breakForce += breakEfficiency * abs(throttleInput)
	
	if not clutch_engaged:
		if currentRPM > revLimit:
			enginePower *= 0.01
		
		currentRPM += enginePower
		
	else: #Simulate clutch slippage
		clutch_time -= delta
		enginePower = 0
		if clutch_time <= 0:
			clutch_engaged = false
	
	var netFriction = (FRICTION_UNITS * breakForce * tireFriction * powerLossFactor * (gearRatio) * delta)##No Delta???
	currentRPM -= netFriction
	#currentRPM *= (1 - (wheelFriction * delta))
	currentRPM = max(currentRPM,0)
	#print("DELTA RPM: ", currentRPM-prevRev)
	var netPower = enginePower - netFriction
	#print("ENGINE POWER: ", enginePower, " NET FRICTION: ", netFriction, " NET TOTAL: ", netPower)
	
	
	if currentRPM > gearRPMLimit:
		currentRPM -= netFriction * 10
	elif currentRPM > gearRPMLimit*throttleInput and netPower > 0:
		currentRPM = gearRPMLimit
	
	return currentRPM

func ShiftGear(gear: int):
	self.currentGear = gear
	clutch_engaged = true
	clutch_time = clutch_timer
	if gear == -1:
		reverse = true
	else:
		reverse = false


#func updateRPMBar():
	#var progress: ProgressBar = menu.get_node("RPMBar")
	#progress.value = currentRPM/gear_redlines[currentGear-1]


#func _on_menu_menu_updated(throttleInputValue: float):
	#throttleInput = throttleInputValue
	#
#
#func _on_menu_gear_changed(gear):
	#currentGear = gear
	#clutch_engaged = true
	#clutch_timer = clutch_time

