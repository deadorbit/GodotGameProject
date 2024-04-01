extends Node2D

var powerCurve: Curve = preload("res://Assets/Engines/SuburuWRXCurve.tres")
var gearRatios = [3.454, 1.947, 1.366, 0.972, 0.738]
var revLimit: int = 7000
var currentGear: int = 1
var idleRPM: int = 700
var enginePowerFactor: float = 1.00
var throttleInput: float = 0.00

var power = 0
var SimEngine: EngineNode

@onready var menu = $Menu

func _ready():
	SimEngine = EngineNode.new(gearRatios, revLimit, powerCurve, enginePowerFactor)

func _process(delta):
	power = SimEngine.EngineLogic(throttleInput, delta)
	updateRPMBar()

func updateRPMBar():
	var progress: ProgressBar = menu.get_node("RPMBar")
	progress.value = power / (revLimit / gearRatios[currentGear-1])


func _on_menu_menu_updated(throttleInputValue: float):
	throttleInput = throttleInputValue
	

func _on_menu_gear_changed(gear):
	currentGear = gear
	SimEngine.shiftGear(gear)
	#clutch_engaged = true
	#clutch_timer = clutch_time

