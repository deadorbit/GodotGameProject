extends Node
signal playerEngineChange()

var playerEngine: EngineNode
var playerSpeed: int = 0
var playerDelta: float = 0.01
var playerMaxRPMGaugeAngle: float = 0
var playerMaxSpeedometerAngle: float = 0
var playerMaxSpeedometerSpeed: float = 0.0
var playerWheels: Array = []

#var playerRPM = 0:
	#get:
		#return playerRPM
	#set(value):
		#playerRPM = value
		#RPMChange.emit()
		#
#var playerRPMLimit: int = 0
