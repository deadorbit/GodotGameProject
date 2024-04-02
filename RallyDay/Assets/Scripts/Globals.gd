extends Node
signal playerEngineChange()

var playerEngine: EngineNode
var playerSpeed: int = 0
var playerDelta: float = 0.01
var playerMaxRPMGaugeAngle: int = 0
var playerMaxSpeedometerAngle: int = 0
var playerWheels: Array = []

#var playerRPM = 0:
	#get:
		#return playerRPM
	#set(value):
		#playerRPM = value
		#RPMChange.emit()
		#
#var playerRPMLimit: int = 0
