class_name Editor
extends Control

## 制谱器

@onready var playground :PlaygroundControl = $PlaygroundControl as PlaygroundControl;
@onready var flowBox :Control = $FlowBox as Control;
@onready var flow :EditorFlow = $FlowBox/FlowPanel as EditorFlow;
@onready var flowScroll :HScrollBar = $FlowBox/Scroll as HScrollBar;
@onready var sliderProgress :Slider = $FlowBox/SliderProgress;
@onready var playLine :Control = $FlowBox/PlayLine;

@onready var buttonPlay := $Edit/VBox/HBoxPlayback/ButtonPlay;
@onready var buttonMenu := $Edit/VBox/HBoxPlayback/ButtonMenu;
@onready var labelTime :Label = $Edit/VBox/LabelTime;

# Map setting
@onready var boxMap := $Edit/VBox/Scroll/VBox/VBoxMap;
@onready var buttonMapSave := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxAction/ButtonSave;
@onready var buttonMapExit := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxAction/ButtonExit;
@onready var editTitle := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxTitle/LineEdit;
@onready var editTitleLatin := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxTitleLatin/LineEdit;
@onready var editAuthor := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxAuthor/LineEdit;
@onready var editAuthorLatin := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxAuthorLatin/LineEdit;
@onready var editMapper := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxMapper/LineEdit;
@onready var spinDiff := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxDiff/SpinBox;
@onready var editMapName := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxMapname/LineEdit;
@onready var buttonAudio := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxAudio/Button;
@onready var buttonVideo := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxVideo/Button;
@onready var spinBpm := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxBpm/SpinBox;
@onready var buttonBg := $Edit/VBox/Scroll/VBox/VBoxMap/HBoxBg/Button;

# Editor setting
@onready var sliderScale := $Edit/VBox/Scroll/VBox/VBoxEditor/HBoxScale/HSlider;
@onready var spinBeats := $Edit/VBox/Scroll/VBox/VBoxEditor/HBoxBeats/SpinBox;
@onready var sliderBgDark := $Edit/VBox/Scroll/VBox/VBoxEditor/HBoxBgDark/HSlider;

# Event setting
@onready var note_choose := $Edit/VBox/Scroll/VBox/VBoxEvent/NoteChoose;

var edit_event_type :BeatMap.EVENT_TYPE; ## 点条就会新出现一个note条 的event type

var event_types :Array = BeatMap.EVENT_TYPE.keys(); ## 列出音符类型的array

signal loaded;
var has_loaded := false;

func _ready():
	# 禁用 virtualJoystic
	playground.enable_virtualJoystick = false;
	playground.buttonMenu.visible = false;
	# 设定模式
	playground.play_mode = playground.PLAY_MODE.EDIT;
	# 同步进度条
	flowScroll.share(sliderProgress);
	# 测试用 加载map
	load_map("user://map/HareHareYukai/map_test.txt");
	
	# 绑定Gui操作
	playground.play_end.connect(func():
		buttonPlay.button_pressed = false;);
	playground.play_jump.connect(func(time):
		buttonPlay.button_pressed = false;);
	buttonPlay.toggled.connect(func(pressed:bool):
		if !playground.started:
			playground.start();
		elif !playground.paused:
			playground.pause();
		else:
			playground.resume(););
	buttonMenu.toggled.connect(func(pressed:bool):
		boxMap.visible = pressed;);
	buttonMapSave.pressed.connect(func():
		playground.beatmap.save_to_file();
		Notifier.notif_popup("saved!", Notifier.COLOR_OK));
	buttonMapExit.pressed.connect(func():
		var editor = get_tree().current_scene;
		Global.unfreeze(Global.mainMenu);
		Global.mainMenu.visible = true;
		get_tree().current_scene = Global.mainMenu;
		get_tree().root.remove_child(editor);
		editor.queue_free(););
	
	sliderScale.value_changed.connect(func(value):
		if !has_loaded: return;
		flow.bar_length = value;
		update_flow_scale();
	);
	spinBeats.value_changed.connect(func(value):
		flow.beat_count = value;);
	sliderBgDark.value_changed.connect(func(value):
		playground.bgpanel_mask.color.a = value;
	);
	
	# 设置值
	sliderBgDark.value = 0.6;
	

## 加载铺面
func load_map(map_file_path: String):
	
	print("[Editor] loading map: ", map_file_path);
	playground.load_map(map_file_path, false);
	has_loaded = true;
	loaded.emit();
	print("[Editor] map loaded.");
	update_flow_scale();
	flowScroll.value_changed.connect(func(value):
		flow.offset = value;
		playground.jump(flow.get_time_by_length(value)););
	playground.play_restart.connect(func():
		flowScroll.value = 0;);
	note_choose.get_child(0).button_group.pressed.connect(func(button):
		print("[Editor] Choose ", String(button.name));
		edit_event_type = event_types[event_types.find(String(button.name))]
	);
	
	print("[Editor] loading properties...");
	var map :BeatMap = playground.beatmap;
	# 加载铺面信息/Event到编辑器
	editTitle.text = map.title;
	editTitleLatin.text = map.title_latin;
	editAuthor.text = map.author;
	editAuthorLatin.text = map.author_latin;
	editMapper.text = map.mapper;
	spinDiff.value = map.diff;
	editMapName.text = map.map_name;
	buttonAudio.text = map.audio_path;
	buttonVideo.text = map.video_path;
	spinBpm.value = map.bpm;
	buttonBg.text = map.bg_image_path;
	# 绑定 gui
	editTitle.text_changed.connect(func(text): map.title = text);
	editTitleLatin.text_changed.connect(func(text): map.title_latin = text);
	editAuthor.text_changed.connect(func(text): map.author = text);
	editAuthorLatin.text_changed.connect(func(text): map.author_latin = text);
	editMapper.text_changed.connect(func(text): map.mapper = text);
	spinDiff.value_changed.connect(func(value): map.diff = value);
	editMapName.text_changed.connect(func(text): map.map_name = text);
	buttonAudio.pressed.connect(func():
		get_file_choose(["*.mp3, *.wav", "Audio"]).file_selected.connect(func(path):
			map.audio_path = copy_to_map_dir(path);
			playground.load_audio()));
	buttonVideo.pressed.connect(func():
		get_file_choose(["*.ogv", "Video"]).file_selected.connect(func(path):
			map.video_path = copy_to_map_dir(path);
			playground.load_video()));
	spinBpm.value_changed.connect(func(value):
		map.bpm = value
		playground.bpm = value);
	buttonBg.pressed.connect(func():
		get_file_choose(["*.png, *.jpg, *.jpeg, *.svg, *.webp, *.bmp", "Image"]).file_selected.connect(func(path):
			map.bg_image_path = copy_to_map_dir(path)
			playground.load_bg_image()));
	print("[Editor] adding events.");
	for event in map.events:
		flow.add_note(
			event.type,
			Vector2(
				flow.get_length_in_flow(event.time),
				flow.get_note_pos_y(event.side)
			),
			Vector2(
				10.0,
				flow.size.y/2.0 - flow.note_margin_vertical * 2.0
			)
		);

func get_file_choose(filters: Array[String]) -> FileDialog:
	var fileDialog = FileDialog.new();
	fileDialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;
	fileDialog.access = FileDialog.ACCESS_FILESYSTEM;
	fileDialog.filters = filters;
	add_child(fileDialog);
	fileDialog.size = Vector2i(1024, 512);
	fileDialog.popup_centered()
	fileDialog.canceled.connect(func():
		remove_child(fileDialog);
		fileDialog.queue_free();
	);
	return fileDialog;

## 将文件存储到铺面目录 然后返回铺面文件夹下的相对路径
func copy_to_map_dir(path: String) -> String:
	DirAccess.make_dir_absolute(path);
	if path.begins_with(playground.beatmap.dir_path): return path;
	var new_relative_path = Global.get_file_name(path)
	DirAccess.copy_absolute(path, playground.beatmap.dir_path + new_relative_path);
	Notifier.notif_popup("File imported!", Notifier.COLOR_OK)
	return new_relative_path;

func update_flow_scale():
	var length := flow.get_length_in_flow(playground.get_audio_length());
	var scale_multiple := length / flow.size.x;
	flow.size.x = length;
	flow.position.x -= (playLine.position.x-flow.position.x)*(scale_multiple-1);
	flowScroll.page = flowBox.size.x;
	flowScroll.max_value = flow.size.x + flowScroll.page;
	sliderProgress.max_value = flowScroll.max_value;
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
