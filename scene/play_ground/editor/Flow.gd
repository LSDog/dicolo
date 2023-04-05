@tool
class_name EditorFlow
extends Panel

@onready var editor := get_parent() as Editor;
@onready var note_crash_stylebox :StyleBox = preload("res://scene/play_ground/editor/note_crash.stylebox");
@onready var note_line_crash_stylebox :StyleBox = preload("res://scene/play_ground/editor/note_line_crash.stylebox");
@onready var note_slide_stylebox :StyleBox = preload("res://scene/play_ground/editor/note_slide.stylebox");

@export var outline_color := Color.LIGHT_YELLOW;
@export var barline_color := Color.LIGHT_BLUE;
@export var beatline_color := Color(0.372549, 0.619608, 0.627451, 0.2);
@export var note_margin_vertical := 4;

signal flow_changed;

## 两小节线间距离
@export var bar_space := 120.0:
	set(value):
		bar_space = value;
		flow_changed.emit();
## 一小节有几拍
@export_range(1,8) var beat_count :int = 4:
	set(value):
		beat_count = value;
		flow_changed.emit();
## 每拍间距离
var beat_space :float = bar_space/beat_count;
## 偏移值(播放进度)
var offset := 0.0:
	set(value):
		offset = value;
		position.x = -offset;

## 鼠标拖动偏移值
var mouse_offset := 0.0;
## 控制中的note
var holding_note :Control;
## 控制中的note的type
var holding_note_type :BeatMap.EVENT_TYPE = 0;
## 所有的note {位置: Vector2, 位置: Note}
var note_map :Dictionary = {};

func _ready():
	flow_changed.connect(func():
		beat_space = bar_space/beat_count;
		queue_redraw();
	);

## 画节拍线，老方法是只画可见部分的节拍线，改为一次全画
func _draw():
	
	var scroll_page := editor.playground.get_rect().size.x;
	var rect := get_global_rect();
	
	# 绘制节拍线
	var h := rect.size.y;
	var x := editor.get_length_in_flow(editor.playground.beatmap.start_time);
	print("beat map start time -> x = ", x);
	while x > 0: x -= bar_space
	while x <= size.x:
		# 小节线
		if x > 0.0:
			draw_line(
				Vector2(x, 0),
				Vector2(x, h),
				barline_color, 1.5, true
			);
		# 每拍线
		var beat_x := 0.0;
		while x + beat_x <= size.x && beat_x <= bar_space:
			draw_line(
				Vector2(x + beat_x, 0),
				Vector2(x + beat_x, h),
				beatline_color, 1, true
			);
			beat_x += beat_space;
		x += bar_space;

func _gui_input(event):
	
	match event.get_class():
		
		"InputEventMouseButton":
			if event.button_index != MOUSE_BUTTON_LEFT: return;
			if event.pressed:
				
				var note_pos = get_note_pos(event.position);
				if rect_overlapped_note(Rect2(note_pos, Vector2.ZERO)): return; # 当前位置存在note则忽略
				
				holding_note_type = editor.edit_note_type;
				
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
				if note_map.has(note_pos):
					var rm_note = note_map.get(note_pos);
					if rm_note != null: remove_note(rm_note);
					return;
			
			if holding_note == null: return;
			
			match holding_note_type:
				BeatMap.EVENT_TYPE.Slide:
					if editor.edit_note_type == BeatMap.EVENT_TYPE.Slide:
						note_pos = get_note_pos(event.position, false);
						var size_x = note_pos.x - holding_note.position.x;
						if size_x < 0: return;
						holding_note.size.x = 10 + size_x;
						mouse_offset -= event.relative.x;
					else:
						note_pos.x += mouse_offset;
						move_note(holding_note, note_pos);
				_:
					if !note_overlapped(holding_note, note_pos):
						move_note(holding_note, note_pos);


func _unhandled_input(event):
	match event.get_class():
		"InputEventKey":
			event = event as InputEventKey;
			return;
			match event.keycode:
				KEY_1:
					editor.choose_note_type(BeatMap.EVENT_TYPE.Crash);
					accept_event();
				_:
					if editor.edit_note_type != BeatMap.EVENT_TYPE.Crash:
						editor.choose_note_type(BeatMap.EVENT_TYPE.Crash);

func get_note_pos_y(side :BeatMap.Event.SIDE) -> float:
	match side:
		BeatMap.Event.SIDE.LEFT:
			return 0.0 + note_margin_vertical;
		BeatMap.Event.SIDE.RIGHT:
			return size.y/2 + note_margin_vertical;
		_:
			return size.y;

func get_note_pos(mouse_pos :Vector2, allow_cross :bool = true) -> Vector2:
	var y = clampf(floor_multiple(mouse_pos.y, size.y/2), 0, size.y/2) + note_margin_vertical;
	if allow_cross:
		return Vector2(floor_multiple(mouse_pos.x, beat_space), y);
	else:
		pass;
		var last_x = size.x;
		var have_last_x = false;
		for pos in note_map.keys():
			if pos.y == holding_note.position.y && pos.x < last_x && pos.x > holding_note.position.x:
				have_last_x = true;
				last_x = pos.x;
		return Vector2(floor_multiple(last_x - beat_space if have_last_x && mouse_pos.x >= last_x else mouse_pos.x, beat_space), y);

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
		BeatMap.EVENT_TYPE.Crash:
			note.add_theme_stylebox_override("panel", note_crash_stylebox);
		BeatMap.EVENT_TYPE.LineCrash:
			note.add_theme_stylebox_override("panel", note_line_crash_stylebox);
		BeatMap.EVENT_TYPE.Slide:
			note.add_theme_stylebox_override("panel", note_slide_stylebox);
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
							holding_note = note;
							holding_note_type = note_type;
							if holding_note_type == BeatMap.EVENT_TYPE.Slide:
								mouse_offset = - event.position.x;
						else:
							holding_note = null;
					# 删除note
					MOUSE_BUTTON_RIGHT:
						if event.pressed:
							remove_note(note);
			
			"InputEventMouseMotion":
				# 拖动持有的note
				
				if holding_note == null || holding_note != note: return;
				var note_pos = event.global_position;
				note_pos.x += offset;
				note_pos = get_note_pos(note_pos);
				move_child(note, 0);
				
				match holding_note_type:
					_:
						if !note_overlapped(note, note_pos):
							move_note(note, note_pos);
					BeatMap.EVENT_TYPE.Slide:
						note_pos.x += 10 + mouse_offset;
						note_pos = get_note_pos(note_pos);
						if note_overlapped(note, note_pos): return;
						move_note(note, note_pos);
	);
	note_map[note.position] = note;
	return note;

func note_overlapped(note :Control, pos :Vector2 = note.get_position()) -> bool:
	var rect = note.get_rect();
	rect.position = pos;
	for map_note in note_map.values():
		if note != map_note && rect.intersects(map_note.get_rect(), true): return true;
	return false;

func rect_overlapped_note(rect :Rect2) -> bool:
	for map_note in note_map.values():
		if rect.intersects(map_note.get_rect(), true): return true;
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

func floor_multiple(value :float, round :float) -> float:
	return floorf(value/round) * round;
