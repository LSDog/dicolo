extends Control

var last_debug_report := 0.0;

@onready var label = $Label;



func _ready():
	pass;

func _process(delta: float):
	if Global.now_time() - last_debug_report <= 0.2: return;
	
	var text := "";
	var fps = DisplayServer.screen_get_refresh_rate();
	text += "fps: %.2f/%.0f" % [1.0/delta, fps];
	label.text = text;
	
	last_debug_report = Global.now_time();
