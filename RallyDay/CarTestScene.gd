extends CharacterBody2D

var turn_speed = 10  # Adjust this for desired turn rate
var user_input = 0.0  # Stores user input (-1 to 1)
var target_angle = 0.0
var max_steering_angle = 60
var smooth_factor = 0.8
var body_rotation_speed = 0.1
var body_angle = 0
@onready var frontWheels: Node2D = $FrontWheels

func _ready():
	position = get_viewport_rect().get_center()

func _physics_process(delta):
	# Calculate turning angle based on user input
	var body_angle = rotation_degrees
	var turn_angle = clamp(user_input * max_steering_angle, -max_steering_angle, max_steering_angle)
	var real_angle = adjust_wheel_rotation(frontWheels, turn_angle, delta)
	body_angle = lerp(body_angle, real_angle + body_angle, body_rotation_speed * delta)
	body_angle = fmod(body_angle, 360.0) # Keep body_angle within 0 to 360

	rotation_degrees = body_angle 

func adjust_wheel_rotation(wheelNode: Node2D, target_angle: float, delta: float):
	var max_steering = 90.0
	var smooth_factor = 0.8
	var return_speed = 5.0
	var steer_amount
	var current_angle

	for i in wheelNode.get_children():
		current_angle = i.rotation_degrees
		var difference = target_angle - current_angle  # No wrapf needed!
		
		## Return-to-center
		#if abs(target_angle) < 0.1:
			#var return_amount = clamp(abs(current_angle) * delta, -return_speed * delta, return_speed * delta)
			#i.rotation_degrees -= return_amount

		# Smooth turning
		steer_amount = lerp(current_angle, target_angle, smooth_factor * delta)
		i.rotation_degrees = clamp(steer_amount, -max_steering, max_steering) 
	
	return steer_amount + current_angle

func _on_h_slider_value_changed(value):
	user_input = value
