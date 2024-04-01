class_name EngineNode extends Node2D

const powerLossFactor: float = 5.0 ## Magic number to modify RPM loss from friction
const gearFriction: float = 0.15 ## Represents ensured power loss over time
const torqueCurve: Curve = preload("res://Assets/Engines/TorqueCurve.tres")

var currentRPM: float = 0#not actally RPM, more equivliant to an arbitary "power" value
var torque: int = 0
var gear_ratios = [3.454, 1.947, 1.336, 0.972, 0.738]
var clutch_engaged: bool = false 
var currentGear: int = 1

var enginePowerFactor: float
var gearRatios: Array
var revLimit: int
var idleRPM: int
var clutch_time: float
var powerCurve: Curve
var clutch_timer: float
var gearCount: int


func _init(gearRatiosValue: Array, revLimitValue: int, powerCurveVaue: Curve, enginePowerFactorValue: float):
	self.gearRatios = gearRatiosValue
	self.revLimit = revLimitValue
	
	self.gearCount = gearRatios.size()
	self.currentGear = 1
	self.powerCurve = powerCurveVaue
	self.clutch_timer = 0.5
	self.enginePowerFactor = enginePowerFactorValue

func EngineLogic(throttleInput, delta):
	var friction = gearFriction
	var gearRatio = gearRatios[currentGear-1]
	var gearRPMLimit = revLimit / gearRatios[currentGear-1]
	#var effectiveThrottle: float = throttleInput
	var potential_power = max(round(powerCurve.sample(currentRPM/revLimit) * revLimit),0)
	var netPower = potential_power * delta * throttleInput * (gearRatio/2) * enginePowerFactor
	
	if not clutch_engaged:
		if currentRPM > revLimit:
			netPower *= 0.01
		
		currentRPM += netPower
		
		if currentRPM > gearRPMLimit:
			currentRPM = gearRPMLimit
			friction += netPower/25
		elif currentRPM > gearRPMLimit*throttleInput:
			friction *= 2
		
	else: #Simulate clutch slippage
		clutch_time -= delta
		if clutch_time <= 0:
			clutch_engaged = false
	
	currentRPM -= (friction * powerLossFactor * gearRatio)
	currentRPM = max(currentRPM,0)
	return currentRPM

func ShiftGear(gear: int):
	self.currentGear = gear
	clutch_engaged = true
	clutch_time = clutch_timer


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

