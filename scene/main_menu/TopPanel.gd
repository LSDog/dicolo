extends PanelContainer

@onready var gamepad: Button = $HBoxInputMode/Gamepad
@onready var virtualJoystick: Button = $HBoxInputMode/VirtualJoystick
@onready var touch: Button = $HBoxInputMode/Touch

func _ready() -> void:
	
	gamepad.pressed.connect(func():
		Notifier.notif_popup("Now using Gamepad for rolling!", Notifier.COLOR_BLUE);
		Global.mainMenu.input_mode = PlaygroundControl.INPUT_MODE.JOYSTICK;
	);
	virtualJoystick.pressed.connect(func():
		Notifier.notif_popup("Now using Virtual Joystick for rolling!", Notifier.COLOR_BLUE);
		Global.mainMenu.input_mode = PlaygroundControl.INPUT_MODE.V_JOYSTICK;
	);
	touch.pressed.connect(func():
		Notifier.notif_popup("Now using finger for tapping!", Notifier.COLOR_BLUE);
		Global.mainMenu.input_mode = PlaygroundControl.INPUT_MODE.TOUCH;
	);
	
	match OS.get_name():
		# 自动在移动设备上选择Touch输入
		# 虽然我压根没打算过支持iOS哈哈哈哈
		"Android", "iOS":
			touch.button_pressed = true;
		# 其他设备使用摇杆
		_:
			gamepad.button_pressed = true;


func _process(delta: float) -> void:
	pass
