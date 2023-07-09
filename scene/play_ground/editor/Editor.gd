class_name Editor
extends Control

## 制谱器

@onready var playground :PlaygroundControl = $PlaygroundControl as PlaygroundControl;
@onready var flowBox :Control = $FlowBox as Control;
@onready var flow :EditorFlow = $FlowBox/FlowPanel as EditorFlow;
@onready var flowScroll :HScrollBar = $FlowBox/Scroll as HScrollBar;
@onready var playLine :Control = $FlowBox/PlayLine;

@onready var labelTime :Label = $Edit/VBox/LabelTime;
@onready var sliderScale := $Edit/VBox/VBoxFlowAdjust/HBoxScale/HSliderScale;
@onready var editBeats := $Edit/VBox/VBoxFlowAdjust/HBoxBeats/LineEditBeats;
@onready var note_choose := $Edit/VBox/NoteChoose;
@onready var buttonPlay := $Edit/VBox/HBoxPlayback/ButtonPlay;
@onready var buttonMenu := $Edit/VBox/HBoxPlayback/ButtonMenu;

var edit_event_type :BeatMap.EVENT_TYPE; ## 正在编辑的

var event_types :Array = BeatMap.EVENT_TYPE.keys(); ## 列出音符类型的array

signal loaded;
var has_loaded := false;

func _ready():
	# 禁用 virtualJoystic
	playground.enable_virtualJoystick = false;
	playground.manuButton.visible = false;
	# 设定模式
	playground.play_mode = playground.PLAY_MODE.EDIT;
	# 修正大小
	if Global.data_has_loaded_setting: currect_scaling();
	else: Global.data_loaded_setting.connect(currect_scaling);
	
	# 测试用 加载map
	load_map("res://map/HareHareYukai/map_normal.txt");
	
	# 绑定Gui操作
	playground.play_end.connect(func():
		buttonPlay.button_pressed = false;
	);
	playground.play_jump.connect(func(time):
		buttonPlay.button_pressed = false;
	);
	buttonPlay.toggled.connect(func(pressed:bool):
		if !playground.started:
			playground.start();
		elif !playground.paused:
			playground.pause();
		else:
			playground.resume();
	);
	
	playground.bgpanel_mask.color.a = 0.6;
	
	sliderScale.value_changed.connect(func(value):
		if !has_loaded: return;
		var scalling :float = value/flow.bar_length;
		flow.bar_length = value;
		update_flow_scale();
	);

## 修正大小
func currect_scaling():
	playground.video_player.scale = Vector2(0.91, 0.91);
	playground.scale /= Global.stretch_scale;


## 加载铺面
func load_map(map_file_path: String):
	
	print("[Editor] loading map: ", map_file_path);
	
	playground.load_map(map_file_path, false);
	
	has_loaded = true;
	loaded.emit();
	print("[Editor] loaded.");
	
	update_flow_scale();
	flowScroll.value_changed.connect(func(value):
		flow.offset = value;
		playground.jump(flow.get_time_by_length(value));
	);
	
	playground.play_restart.connect(func():
		flowScroll.value = 0;
	);
	
	note_choose.get_child(0).button_group.pressed.connect(func(button):
		print("[Editor] Choose ", String(button.name));
		edit_event_type = event_types.find(String(button.name));
	);
	
	# 加载铺面到编辑器
	for event in playground.beatmap.events:
		flow.add_note(
			event.event_type,
			Vector2(
				flow.get_length_in_flow(event.time),
				flow.get_note_pos_y(event.side)
			),
			Vector2(
				10.0,
				flow.size.y/2.0 - flow.note_margin_vertical * 2.0
			)
		);
	#for key in BeatMap.EVENT_TYPE.keys():
	#	NOTE_TYPE_MAP[key] = BeatMap.EVENT_TYPE[key];

func update_flow_scale():
	var value = flowScroll.value;
	var length := flow.get_length_in_flow(playground.get_audio_length());
	var scale_multiple := length / flow.size.x;
	flow.position.x -= (playLine.position.x-flow.position.x)*(scale_multiple-1)/2.0;
	flow.size.x = length;
	flowScroll.page = flowBox.size.x;
	flowScroll.max_value = flow.size.x + flowScroll.page;
	flow.rescale_contents(scale_multiple);

func _process(_delta: float) -> void:
	if playground.started && !playground.ended && !playground.paused:
		labelTime.text = get_time_string(playground.play_time
			) + " : " + get_time_string(playground.get_audio_length());
		var x = flow.get_length_in_flow(playground.play_time);
		flowScroll.set_value_no_signal(x);
		flowScroll.queue_redraw();
		flow.offset = x;

func get_time_string(time: float) -> String:
	var minute := floori(time/60);
	var sec := floori(time - minute*60);
	var point := floori((time - floorf(time))*100);
	return "%02d %02d %02d" % [minute, sec, point];

func choose_note_type(type :BeatMap.EVENT_TYPE):
	(note_choose.find_child(BeatMap.EVENT_TYPE.find_key(type)) as Button).button_pressed = true;
	edit_event_type = type;

func _input(event: InputEvent):
	if event.is_action_pressed("play"):
		accept_event();
		buttonPlay.button_pressed = !buttonPlay.button_pressed;

func _unhandled_input(event):
	if !visible: return;
	match event.get_class():
		"InputEventMouseButton":
			event = event as InputEventMouseButton;
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					flowScroll.value -= 10;
					accept_event();
				MOUSE_BUTTON_WHEEL_DOWN:
					flowScroll.value += 10;
					accept_event();
