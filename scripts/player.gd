extends CharacterBody3D

#movement variables
const defaultheight = 1.63
const crouchheight = 0.71
const crouchSpeed = 1.205232
const walkSpeed = 3.6176 
const runSpeed = 6.0928
const jumpVelocity = 5.0
const crouchtransisitionspeed = 7
var acceleration = 0.20 #0.01
var speed
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var input_dir
var lean_dir
var direction
var sliding = false

#Player Stuff
@onready var pcol := $CollisionShape3D
@onready var neck := $Neck
@onready var camera := $Neck/Camera3D

#Stair stepper
const maxStepHeight = 0.5;
var snappedToStairsLastFrame = false;
var lastFrameOnFloor = -INF;

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	speed = walkSpeed

func _input(event):
	if event is InputEventMouseMotion:
		neck.rotate_y(-event.relative.x * get_viewport().get_final_transform().x.x * 0.01)
		camera.rotate_x(-event.relative.y * get_viewport().get_final_transform().y.y * 0.01)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
func _process(delta: float) -> void:
	movement(delta)
	
func movement(delta):
	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and !sliding:
		velocity.y = jumpVelocity
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	#moving
	direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() * speed
	if direction:
		if is_on_floor() or snappedToStairsLastFrame:
			lastFrameOnFloor = Engine.get_physics_frames()
			if Input.is_action_pressed("sprinting"):
				lerp_speed(20.0, speed, runSpeed, delta, acceleration)
			else:
				lerp_speed(10.0, speed, walkSpeed, delta, acceleration)
		else:
			lerp_speed(10.0, speed, walkSpeed, delta, acceleration)
			velocity.y -= gravity * delta 
	elif !direction:
		if !is_on_floor() or !snappedToStairsLastFrame:
			lerp_speed(2.0, speed, 0.0, delta, acceleration * 10)
			velocity.y -= gravity * delta
		if is_on_floor() or snappedToStairsLastFrame:
			lerp_speed(10.0, speed, walkSpeed, delta)
			
	
	# Crouching and sliding
	if Input.is_action_just_released("crouching"):
		if speed <= walkSpeed:
			speed = walkSpeed
	if Input.is_action_pressed("crouching"):
		#%StairsBelowRaycast.target_position.y = -0.75
		pcol.shape.size.y -= crouchtransisitionspeed * delta
		speed = crouchSpeed
	elif !self.test_move(self.transform, Vector3(0,0.3,0)):
		pcol.shape.size.y += crouchtransisitionspeed * delta
		#%StairsBelowRaycast.target_position.y = -1.75
	pcol.shape.size.y = clamp(pcol.shape.size.y, crouchheight, defaultheight)
	
	#begin moving player
	#if not snap_up_to_stairs_check(delta):
	move_and_slide()
		#snap_down_to_stairs_check(delta)
	
func lerp_speed(lerpSpeed, startSpeed, setSpeed, delta, accel = 1):
	velocity.x = lerp(velocity.x, direction.x, delta * lerpSpeed)
	velocity.z = lerp(velocity.z, direction.z, delta * lerpSpeed)
	speed = lerp(startSpeed, setSpeed, delta * lerpSpeed * accel)
	
func snap_down_to_stairs_check(delta) -> void:
	var didSnap = false
	var floorBelow : bool = %StairsBelowRaycast.is_colliding() and not is_surface_too_steep(%StairsBelowRaycast.get_collision_normal())
	var wasOnFloorLastFrame = Engine.get_physics_frames() - lastFrameOnFloor == 1
	if not is_on_floor() and velocity.y <= 0  and (wasOnFloorLastFrame or snappedToStairsLastFrame) and floorBelow:
		var bodyTestResult = PhysicsTestMotionResult3D.new()
		if run_body_test_motion(self.global_transform, Vector3(0, -maxStepHeight, 0), bodyTestResult):
			var translateY = bodyTestResult.get_travel().y
			self.position.y = lerp(self.position.y, self.position.y + translateY, delta * 20) 
			lerp_speed(0.2, speed, runSpeed, delta * 2.0)
			didSnap = true
	snappedToStairsLastFrame = didSnap
	
func snap_up_to_stairs_check(delta) -> bool:
	if not is_on_floor() and not snappedToStairsLastFrame: return false
	var expectedMoveMotion = self.velocity * Vector3(1, 0, 1) * delta
	var stepPosWithClearance = self.global_transform.translated(expectedMoveMotion + Vector3(0, maxStepHeight * 2, 0))
	var downCheckResult = PhysicsTestMotionResult3D.new()
	if (run_body_test_motion(stepPosWithClearance, Vector3(0, -maxStepHeight * 2, 0), downCheckResult)
	and (downCheckResult.get_collider().is_class("StaticBody3D") or downCheckResult.get_collider().is_class("CSGShape3D"))):
		var stepHeight = ((stepPosWithClearance.origin + downCheckResult.get_travel()) - self.global_position).y
		if stepHeight > maxStepHeight or stepHeight <= 0.01 or (downCheckResult.get_collision_point() - self.global_position).y > maxStepHeight: return false
		%StairsForwardRaycast.global_position = downCheckResult.get_collision_point() + Vector3(0, maxStepHeight, 0) + expectedMoveMotion.normalized() * 0.1
		%StairsForwardRaycast.force_raycast_update()
		if %StairsForwardRaycast.is_colliding() and not is_surface_too_steep(%StairsForwardRaycast.get_collision_normal()):
			self.global_position = stepPosWithClearance.origin + downCheckResult.get_travel()
			snappedToStairsLastFrame = true
			return true
	return false
	
func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle
	
func run_body_test_motion(from: Transform3D, motion: Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)
