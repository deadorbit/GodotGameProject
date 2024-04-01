extends CanvasLayer

const RPMLightOff: Color = Color(0.255, 0, 0.012)
const RPMLightOn: Color = Color(0.916, 0, 0.124)

@onready var gearText = $HBoxContainer/Text/GearInfo
@onready var PowerText = $HBoxContainer/Text/PowerInfo
@onready var SpeedText = $HBoxContainer/Text/SpeedText
@onready var RPMNeedle = $RPMGauge/Needle
@onready var RPMLight = $RPMGauge/Light
#@onready var RPMBar: ProgressBar = $RPMBar
#@onready var speedBar: ProgressBar = $SpeedBar

signal menuUpdated(throttle)
signal gearChanged(gear: int)

var throttle: float = 0.00
var gear: int = 1

func _ready():
	Globals.connect("playerEngineChange",_on_playerEngineChange)


func _on_gear_changed():
	gearText.text = "Gear: %d" % gear


func _on_playerEngineChange():
	var playerEngine: EngineNode = Globals.playerEngine
	var playerSpeed: int = round(Globals.playerSpeed)
	var RPM = playerEngine.currentRPM
	var currentGear = playerEngine.currentGear
	var gearRatios = playerEngine.gearRatios
	var revLimit = playerEngine.revLimit
	var gearLimit = revLimit / gearRatios[currentGear-1]
	
	_UpdateRPMGauge(RPM, gearLimit)
	#RPMBar.value = RPM/gearLimit
	#speedBar.value = playerSpeed
	
	PowerText.text = "Power: %.2f" % RPM
	gearText.text = "Gear: %d" % currentGear

func _UpdateRPMGauge(RPM, gearLimit):
	var RevPercent = RPM/gearLimit
	var revMaxAngle = Globals.playerMaxRPMGaugeAngle
	var revAngle = clamp(RevPercent * revMaxAngle,0, revMaxAngle)
	
	if (RevPercent > 0.8):
		RPMLight.modulate = RPMLightOn
	else:
		RPMLight.modulate = RPMLightOff

	# Update rotation using global delta
	RPMNeedle.rotation_degrees = lerp(RPMNeedle.rotation_degrees, revAngle, 0.5 * Globals.playerDelta)
