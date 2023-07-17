## 包含一张图所有信息的类
class_name BeatMap
extends Resource

## 音符类型
enum EVENT_TYPE {None, Note, Hit, Slide, Cross, Bound, Start, Bpm, End};
## 总分
const TOTAL_SCORE :float = 1000000;

var loaded :bool = false; ## 是否加载完毕

var dir_path :String; ## 铺面文件夹路径
var file_path :String; ## 铺面文件路径

var title :String; ## 歌曲标题
var title_latin :String; ## 歌曲标题(拉丁字母)
var author :String; ## 演唱者
var author_latin :String; ## 演唱者(拉丁字母)
var map_name :String; ## 铺面名称
var mapper :String; ## 作图者
var diff: float; ## 难度
var audio_path :String; ## 音频文件路径
var video_path :String; ## 视频文件路径
var bpm: float; ## 默认Bpm
var bg_image_path :String; ## 背景图片路径
var lrc_path :String; ## 歌词路径
var events :Array[Event] = []; ## 音符/事件等

var start_time: float; ## 开始时间（来自第一个event的时间）
var end_time: float; ## 结束时间（来自最后一个_end或的时间）
var last_event_time: float; ## 最后一个event的时间

var event_counts :Array[int] = []; ## 记录铺面中事件的数量，顺序同EVENT_TYPE
var note_count :int = 0; ## 音符的总数
var note_scores :Array[float] = []; ## 记录note的分值，顺序同EVENT_TYPE

## 构造器。需要当前铺面目录和已经打开的 [FileAccess] ([method FileAccess.open])
## ignore_notes 会忽略所有notes 但是保留其他event
func _init(dir :String, file :FileAccess, ignore_notes :bool = false):
	resource_name = "BeatMap";
	event_counts.resize(EVENT_TYPE.size());
	event_counts.fill(0);
	note_scores.resize(EVENT_TYPE.size());
	note_scores.fill(0.0);
	if file == null || !file.is_open(): return;
	if !dir.ends_with('/'): dir += '/';
	dir_path = dir;
	file_path = file.get_path();
	# 获取第一行的标识内容并检验
	var head_line = file.get_line();
	if head_line != "!dicolo_map_v1":
		file.close();
		return;
	var key :String = "";
	var value :String = "";
	var in_event :bool = false;
	var line :String;
	while file.get_position() < file.get_length():
		# 获取下一行
		line = file.get_line();
		# 去掉注释
		line = line.substr(0, line.find("//"));
		if line.is_empty(): continue;
		# 读取event时
		if in_event:
			add_event(line);
		else:
			# 读取其他单行键值
			var array := line.split(':', true, 2);
			if array.size() < 2: continue;
			key = array[0];
			value = array[1];
			match key:
				"title": title = value;
				"title_latin": title_latin = value;
				"author": author = value;
				"author_latin": author_latin = value;
				"mapper": mapper = value;
				"diff": diff = -1.0 if !value.is_valid_float() else value.to_float();
				"map_name": map_name = value;
				"audio": audio_path = value;
				"video": video_path = value;
				"bpm": bpm = 0.0 if !value.is_valid_float() else value.to_float();
				"bg": bg_image_path = value;
				"lrc": lrc_path = value;
				"events": in_event = true;
	file.close();
	start_time = 0.0 if events.is_empty() else events[0].time;
	last_event_time = 0.0 if events.is_empty() else events[-1].time;
	# 计算分值
	if !ignore_notes:
		var ratio_hit :float = event_counts[EVENT_TYPE.Hit];
		var ratio_slide :float = event_counts[EVENT_TYPE.Slide] / 4.0;
		var ratio_cross :float = event_counts[EVENT_TYPE.Cross];
		var ratio_bound :float = event_counts[EVENT_TYPE.Bound];
		var ratio_all = ratio_hit + ratio_slide + ratio_cross + ratio_bound;
		note_scores[EVENT_TYPE.Hit] = ratio_hit/ratio_all * TOTAL_SCORE / event_counts[EVENT_TYPE.Hit];
		note_scores[EVENT_TYPE.Slide] = ratio_slide/ratio_all * TOTAL_SCORE / event_counts[EVENT_TYPE.Slide];
		note_scores[EVENT_TYPE.Cross] = ratio_cross/ratio_all * TOTAL_SCORE / event_counts[EVENT_TYPE.Cross];
		note_scores[EVENT_TYPE.Bound] = ratio_bound/ratio_all * TOTAL_SCORE / event_counts[EVENT_TYPE.Bound];
	loaded = true;

func get_audio_path():
	return dir_path + audio_path;
func get_video_path():
	return dir_path + video_path;
func get_bg_image_path():
	return dir_path + bg_image_path;
func get_lrc_path():
	return dir_path + lrc_path;

## 接受1行带时间的event形式，如 "0.6 _start" 或 "1.93 c/l/-135 c/r/-90"
## ignore_notes 会忽略所有note 但是不忽略其他event
func add_event(event_str :String, ignore_notes :bool = false):
	if event_str == null || event_str.is_empty(): return;
	var event_split := event_str.split(" ", false);
	if event_split.size() < 2: return;
	if !event_split[0].is_valid_float(): return;
	var time := event_split[0].to_float();
	for i in range(1, event_split.size()):
		if event_split[i].begins_with("_"): # 事件
			add_other_event(time, event_split[i]);
		else: # 音符
			if !ignore_notes: add_note(time, event_split[i]);

func add_other_event(time: float, event_string: String):
	var data_split := event_string.split('/');
	match data_split[0]:
		"_start":
			add_and_count_event(Event.Start.new(time));
		"_end":
			end_time = time;
			add_and_count_event(Event.End.new(time));
		"_bpm":
			if data_split.size() < 2:
				push_warning("%f _bpm data wrong" % time);
				return;
			add_and_count_event(Event.Bpm.new(time, data_split[1].to_float()));

## 接受单个音符形式，如 c/r/135
func add_note(time: float, note_string :String):
	if note_string.is_empty(): return;
	var note_split = note_string.split('/');
	match note_split[0]:
		"h": # hit
			if note_split.size() < 4:
				push_warning("%f hit data wrong" % time);
				return;
			add_and_count_event(Event.Note.Hit.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT, \
				0.0 if !note_split[2].is_valid_float() else note_split[2].to_float(), \
				0.0 if !note_split[3].is_valid_float() else note_split[3].to_float()
			));
		"s": # slide
			if note_split.size() < 3:
				push_warning("%f slide data wrong" % time);
				return;
			add_and_count_event(Event.Note.Slide.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT, \
				0.0 if !note_split[2].is_valid_float() else note_split[2].to_float(),
			));
		"c": # cross
			if note_split.size() < 4:
				push_warning("%f hit data wrong" % time);
				return;
			add_and_count_event(Event.Note.Cross.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT, \
				0.0 if !note_split[2].is_valid_float() else note_split[2].to_float(), \
				0.0 if !note_split[3].is_valid_float() else note_split[3].to_float()
			));
		"b": # bound
			if note_split.size() < 2:
				push_warning("%f bound data wrong" % time);
				return;
			add_and_count_event(Event.Note.Bound.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT
			));

## 将 event 放进列表并计数
func add_and_count_event(event: Event):
	events.append(event);
	event_counts[event.type] += 1;

## 保存铺面
func save_to_file():
	var file = FileAccess.open(file_path, FileAccess.WRITE);
	file.store_string(to_file_string());
	file.flush();
	file.close();
	print("[BeatMap] saved ", file_path);

## 输出为格式化的String
func to_file_string() -> String:
	var values :PackedStringArray = [];
	values.append("!dicolo_map_v1");
	append_no_empty(values, ["title:", title]);
	append_no_empty(values, ["title_latin:", title_latin]);
	append_no_empty(values, ["author:", author]);
	append_no_empty(values, ["author_latin", author_latin]);
	append_no_empty(values, ["mapper:", mapper]);
	append_no_empty(values, ["diff:", str(diff)]);
	append_no_empty(values, ["map_name:", map_name]);
	append_no_empty(values, ["audio:", audio_path]);
	append_no_empty(values, ["video:", video_path]);
	append_no_empty(values, ["bpm:", str(bpm)]);
	append_no_empty(values, ["bg:", bg_image_path]);
	append_no_empty(values, ["lrc:", lrc_path]);
	
	values.append("\n");
	
	var event_array :PackedStringArray = [];
	for event in events:
		event_array.append(event.to_file_string());
	values.append("events:\n" + "\n".join(event_array));
	
	return "\n".join(values);

func append_no_empty(array: PackedStringArray, str_array: Array):
	if str_array != null && !str_array.is_empty() && !str_array.has(null) && !str_array.has(""):
		array.append("".join(str_array));

class Event:
	
	# Event 类型（get_class不能用）
	var type = EVENT_TYPE.None;
	
	## 执行的时间(s)
	var time: float;
	
	## 所在track的位置
	var side :SIDE;
	## 位置常量
	enum SIDE {OTHER=-1, LEFT=0, RIGHT=1}
	static var side_str := {SIDE.OTHER:'', SIDE.LEFT:'l', SIDE.RIGHT:'r'};
	
	func _init(p_time: float, p_side: SIDE = SIDE.OTHER):
		self.time = p_time;
		self.side = p_side;
	
	func to_file_string() -> String:
		return "";
	
	## 音符
	class Note:
		extends Event;
		
		func _init(p_time: float, p_side: SIDE):
			super._init(p_time, p_side);
			self.type = EVENT_TYPE.Note;
		
		class Hit:
			extends Note;
			
			var deg: float;
			var deg_end: float;
			func to_file_string():
				return "%f h/%s/%d/%d" % [time,side_str[side],deg,deg_end];
			func _init(p_time: float, p_side: SIDE, p_deg: float, p_deg_end: float):
				super._init(p_time, p_side);
				self.deg = p_deg;
				self.deg_end = p_deg_end;
				self.type = EVENT_TYPE.Hit;
		
		class Slide:
			extends Note;
			
			var deg: float;
			func to_file_string():
				return "%f s/%s/%d" % [time,side_str[side],deg];
			func _init(p_time: float, p_side: SIDE, p_deg: float):
				super._init(p_time, p_side);
				self.deg = p_deg;
				self.type = EVENT_TYPE.Slide;
		
		class Cross:
			extends Note;
			
			var deg: float;
			var deg_end: float;
			func to_file_string():
				return "%f h/%s/%d/%d" % [time,side_str[side],deg,deg_end];
			func _init(p_time: float, p_side: SIDE, p_deg: float, p_deg_end: float):
				super._init(p_time, p_side);
				self.deg = p_deg;
				self.deg_end = p_deg_end;
				self.type = EVENT_TYPE.Cross;
		
		class Bound:
			extends Note;
			
			func to_file_string():
				return "%f b/%s" % [time,side_str[side]];
			func _init(p_time: float, p_side: SIDE):
				super._init(p_time, p_side);
				self.type = EVENT_TYPE.Bound;
	
	## 开始
	class Start:
		extends Event;
		func to_file_string() -> String:
			return "%f _start" % time;
		func _init(p_time: float):
			super._init(p_time, SIDE.OTHER);
			type = EVENT_TYPE.Start;

	## 结束
	class End:
		extends Event;
		func to_file_string() -> String:
			return "%f _end" % time;
		func _init(p_time: float):
			super._init(p_time, SIDE.OTHER);
			type = EVENT_TYPE.End;
	
	## bpm更改
	class Bpm:
		extends Event;
		
		var bpm: float;
		func to_file_string() -> String:
			return "%f _bpm %f" % time;
		func _init(p_time: float, p_bpm: float):
			super._init(p_time, SIDE.OTHER);
			self.bpm = p_bpm;
			type = EVENT_TYPE.Bpm;
	
