extends CanvasLayer

const RPMLightOff: Color = Color(0.255, 0, 0.012)
const RPMLightOn: Color = Color(0.916, 0, 0.124)

@onready var gearText = $HBoxContainer/Text/GearInfo
@onready var PowerText = $HBoxContainer/Text/PowerInfo
@onready var SpeedText = $HBoxContainer/Text/SpeedInfo
@onready var RPMNeedle = $RPMGauge/Needle
@onready var RPMLight = $RPMGauge/Light
@onready var SpeedometerNeedle = $SpeedometerGauge/Needle
@onready var SpeedometerElectronic = $SpeedometerGauge/SpeedometerElectronics

#TextB
@onready var recoilText = $HBoxContainer/TextB/RecoilInfo

signal menuUpdated(throttle)
signal gearChanged(gear: int)

var throttle: float = 0.00
var gear: int = 1
var SpeedometerElectronicSpeedLabel: Label
var SpeedometerElectronicGearLabel: Label

func _ready():
	SpeedometerElectronicSpeedLabel = SpeedometerElectronic.get_node("ElectronicsLabel")
	SpeedometerElectronicGearLabel = SpeedometerElectronic.get_node("ElectronicsGearLabel")
	Globals.connect("playerEngineChange",_on_playerEngineChange)


func _on_gear_changed():
	gearText.text = "Gear: %d" % gear


func _on_playerEngineChange():
	var playerEngine: EngineNode = Globals.playerEngine
	var playerSpeed: Vector2 = Globals.playerSpeed
	var playerSpeedMPH: float =  Globals.SpeedToMPH(playerSpeed)
	var RPM = playerEngine.currentRPM
	var currentGear = playerEngine.currentGear
	var gearRatios = playerEngine.gearRatios
	var revLimit = playerEngine.revLimit
	var gearLimit = revLimit / gearRatios[currentGear-1]
	var recoil: Vector2 = Globals.playerInverseVelocity
	
	_UpdateRPMGauge(RPM, gearLimit)
	_UpdateSpeedometerGauge(playerSpeedMPH, currentGear)
	
	PowerText.text = "Power: %.2f" % RPM
	gearText.text = "Gear: %d" % currentGear
	SpeedText.text = "Speed: %d MPH" % playerSpeedMPH
	
	recoilText.text = "Recoil Force: (%d, %d)" % [recoil.x,recoil.y]
	
	var tractionFactor = Globals.CalculateTractionFactor(playerSpeed, Globals.playerTopSpeed)

func _UpdateRPMGauge(RPM, gearLimit):
	var RevPercent = RPM/gearLimit
	var revMaxAngle = Globals.playerMaxRPMGaugeAngle
	var revAngle = clamp(RevPercent * revMaxAngle,0.0, revMaxAngle)
	
	if (RevPercent > 0.8):
		RPMLight.modulate = RPMLightOn
	else:
		RPMLight.modulate = RPMLightOff

	# Update rotation using global delta
	RPMNeedle.rotation_degrees = lerp(RPMNeedle.rotation_degrees, revAngle, 2 * Globals.playerDelta)
	
func _UpdateSpeedometerGauge(speed: float, currentGear: int):
	var maxSpeedAngle = Globals.playerMaxSpeedometerAngle
	var maxSpeed = Globals.playerMaxSpeedometerSpeed
	var speedAngle: float = clamp(float(speed/maxSpeed) * maxSpeedAngle,0.0,maxSpeedAngle)
	
	SpeedometerNeedle.rotation_degrees = lerp(SpeedometerNeedle.rotation_degrees, speedAngle, 2 * Globals.playerDelta)
	
	SpeedometerElectronicSpeedLabel.text = "SPEED: \n %d" % speed
	SpeedometerElectronicGearLabel.text = "GEAR: \n %d" % currentGear
	
	#print("SPEEDOMETER ANGLE: ", speedAngle)
