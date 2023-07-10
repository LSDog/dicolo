class_name EditorFlow
extends Panel

## 制谱器的时间轴

@onready var editor :Editor = $"../.." as Editor;
@onready var box :Control = $".." as Control;
@onready var playLine :Control = $"../PlayLine";
@onready var scroll :Control = $"../Scroll" as HScrollBar;
@onready var note_hit_stylebox :StyleBox = preload("res://scene/editor/note_hit.stylebox");
@onready var note_slide_stylebox :StyleBox = preload("res://scene/editor/note_slide.stylebox");
@onready var note_bounce_stylebox :StyleBox = preload("res://scene/editor/note_bounce.stylebox");

@export var outline_color := Color.LIGHT_YELLOW;
@export var barline_color := Color.LIGHT_BLUE;
@export var beatline_color := Color(0.372549, 0.619608, 0.627451, 0.2);
@export var note_margin_vertical := 4;

var flow_start_offset :float = 0.0; ## flow 开始_draw()的距离
var beat_offset :float = 0.0;

signal flow_changed; # flow设定被更改(小节线距离,拍数)的信号

## 两小节线间距离
@export_range(10,300) var bar_length :float = 120.0:
	set(value):
		bar_length = value;
		flow_changed.emit();
## 一小节有几拍
@export_range(1,32) var beat_count :int = DEFAULT_BEAT_COUNT:
	set(value):
		beat_count = value;
		flow_changed.emit();
const DEFAULT_BEAT_COUNT := 4;

var beat_space :float = bar_length/beat_count; ## 每拍间距离
## 偏移值(播放进度)
var offset := 0.0:
	set(value):
		offset = value;
		position.x = -offset + playLine.position.x;
		flow_changed.emit();

## 鼠标拖动偏移值
var mouse_offset := 0.0;
## 控制中的note
var holding_note :Control;
## 控制中的note的type
var holding_note_type :BeatMap.EVENT_TYPE = BeatMap.EVENT_TYPE.None;
## 所有的note {位置: Vector2, 音符: Note}
var note_map :Dictionary = {};

func _ready():
	flow_changed.connect(func():
		beat_space = bar_length/beat_count;
		queue_redraw();
	);
	
	_ready_later.call_deferred();

func _ready_later():
	offset = 0.0;

## 画节拍线，老方法是只画可见部分的节拍线，改为一次全画
func _draw():
	
	if !editor.has_loaded: return;
	
	#var scroll_page := editor.playground.get_rect().size.x;
	var rect := get_rect();
	draw_rect(Rect2(Vector2.ZERO, rect.size), outline_color, false);
	draw_line(Vector2(0,rect.size.y/2.0), Vector2(size.x,rect.size.y/2.0), outline_color);
	
	# 节拍线
	var h := size.y;
	var x := get_length_in_flow(editor.playground.beatmap.start_time);
	while x >= 0: x -= bar_length
	flow_start_offset = x;
	beat_offset = fmod(flow_start_offset, beat_space);
	while x <= size.x:
		# 小节线
		if x >= 0:
			draw_line(
				Vector2(x, 0),
				Vector2(x, h),
				barline_color, 1.5, true
			);
		# 每拍线
		var beat_x := 0.0;
		while x + beat_x <= size.x && beat_x <= bar_length:
			if x >= 0:
				draw_line(
					Vector2(x + beat_x, 0),
					Vector2(x + beat_x, h),
					beatline_color, 1, true
				);
			beat_x += beat_space;
		x += bar_length;

func rescale_contents(multiple: float):
	# move note position
	var new_note_map :Dictionary = {};
	for pos in note_map:
		var note = note_map[pos];
		pos.x *= multiple;
		note.position = pos;
		new_note_map[pos] = note;
	note_map = new_note_map;

func _gui_input(event):
	
	match event.get_class():
		
		"InputEventMouseButton": match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				scroll.value -= 10;
			MOUSE_BUTTON_WHEEL_DOWN:
				scroll.value += 10;
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					var note_pos = get_note_pos(event.position);
					if pos_overlap_note(note_pos): return; # 当前位置存在note则忽略
					holding_note_type = editor.edit_event_type;
					var note_panel = add_note(holding_note_type, note_pos);
					holding_note = note_panel;
				else:
					holding_note = null;
					mouse_offset = 0;
		
		"InputEventMouseMotion":
			# 移动持有的note
			event = event as InputEventMouseMotion;
			var note_pos = get_note_pos(event.position);
			
			if event.button_mask == MOUSE_BUTTON_MASK_RIGHT: # 右键划过删除
				var visible_flow_rect = box.get_rect().intersection(get_global_rect());
				for pos in note_map:
					if !visible_flow_rect.has_point(pos): continue;
					var note = note_map.get(pos);
					if !note.get_global_rect().has_point(event.position): continue;
					note_map.erase(pos);
					remove_child(note);
					note.queue_free();
			
			if holding_note == null: return;
			
			if !pos_overlap_note(note_pos):
				move_note(holding_note, note_pos);

func get_length_in_flow(time :float) -> float:
	return time * editor.playground.bpm / 60.0 * beat_space;

func get_time_by_length(length :float) -> float:
	return length / beat_space / editor.playground.bpm * 60.0;

func get_note_pos_y(side :BeatMap.Event.SIDE) -> float:
	match side:
		BeatMap.Event.SIDE.LEFT:
			return 0.0 + note_margin_vertical;
		BeatMap.Event.SIDE.RIGHT:
			return size.y/2 + note_margin_vertical;
		_:
			return size.y;

func get_note_pos(mouse_pos :Vector2) -> Vector2:
	var y := clampf(floor_multiple(mouse_pos.y, size.y/2.0), 0.0, size.y/2.0
		) + note_margin_vertical;
	return Vector2(
		floor_multiple(mouse_pos.x-beat_offset, beat_space)+beat_offset
	, y);

func add_note(
		note_type: BeatMap.EVENT_TYPE,
		p_note_pos: Vector2,
		p_size :Vector2 = Vector2(10, size.y/2 - note_margin_vertical*2)
	) -> Panel:
	
	var note := Panel.new();
	#note.name = 'note_' + BeatMap.EVENT_TYPE.find_key(note_type);
	note.position = p_note_pos;
	note.size = p_size;
	
	match note_type:
		BeatMap.EVENT_TYPE.Hit:
			note.add_theme_stylebox_override("panel", note_hit_stylebox);
		BeatMap.EVENT_TYPE.Slide:
			note.add_theme_stylebox_override("panel", note_slide_stylebox);
		BeatMap.EVENT_TYPE.Bounce:
			note.add_theme_stylebox_override("panel", note_bounce_stylebox);
		_:
			print("not support note type in edtor: ", note_type);
			return;
	
	add_child(note);
	
	# note 自己的点击事件等
	note.gui_input.connect(func(event):
		
		match event.get_class():
			
			"InputEventMouseButton":
				match event.button_index:
					# 开始拖动note
					MOUSE_BUTTON_LEFT:
						if event.pressed:
							top_note(note);
							holding_note = note;
							holding_note_type = note_type;
						else:
							holding_note = null;
					# 删除note
					MOUSE_BUTTON_RIGHT:
						if event.pressed:
							remove_note(note);
			
			"InputEventMouseMotion":
				# 拖动持有的note
				if holding_note == null || holding_note != note: return;
				top_note(note);
				var note_pos = event.global_position;
				note_pos.x += offset;
				note_pos.y -= global_position.y;
				note_pos = get_note_pos(note_pos);
				var note_beat_offset := fmod(note.position.x-beat_offset, beat_space);
				print(note_beat_offset);
				note_pos.x += note_beat_offset;
				if !pos_overlap_note(note_pos):
					move_note(note, note_pos);
	);
	note_map[note.position] = note;
	return note;

func pos_overlap_note(pos :Vector2) -> bool:
	for map_note in note_map.values():
		# 改为同坐标禁止而非相交禁止
		if map_note.position == pos: return true;
	return false;

func move_note(note :Control, pos :Vector2):
	note_map.erase(note.position);
	note.position = pos;
	note_map[pos] = note;

func remove_note(note :Control):
	if !note_map.has(note.position): return;
	note_map.erase(note.position);
	remove_child(note);
	note = null;

func top_note(note: Control):
	move_child(note, -1);

func floor_multiple(value :float, round_float :float) -> float:
	return floorf(value/round_float) * round_float;
