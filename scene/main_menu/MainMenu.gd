extends Control

var debug_label_last_report = 0;

func _ready():
	Global.scene_MainMenu = self;

func _process(_delta):
	var time = Time.get_unix_time_from_system();
	if time - debug_label_last_report >= 0.5:
		$Debugs/DebugLabel.text = "debug: [dpi]%d [fps]%d [mem]%.1f/%.1fM [acc]%s" % [
			DisplayServer.screen_get_dpi(), Engine.get_frames_per_second(),
			OS.get_static_memory_usage()/1024.0/1024.0,
			OS.get_static_memory_peak_usage()/1024.0/1024.0,
			Input.get_accelerometer()
		];
		debug_label_last_report = time;
