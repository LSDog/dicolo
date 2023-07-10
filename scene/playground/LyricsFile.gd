class_name LyricsFile
extends RefCounted

enum TagId { al,ar,au,by,re,ti,ve }
## 是否成功加载
var loaded = false;
## 信息tag
var tags := {};
## 歌词 [[4.08: "歌词1"], [65.01: "歌词2"]]
var lyrics := [];

func _init(lrc_file: FileAccess):
	
	if !FileAccess.file_exists(lrc_file.get_path()): return;
	var value_array := FileAccess.get_file_as_string(lrc_file.get_path()).split("\n");
	lrc_file.close();
	
	for value_line in value_array:
		
		if !value_line.begins_with("["): continue;
		if value_line.ends_with("]"):
			# [tag:value]
			var tag_value := value_line.substr(1, value_line.length()-2).split(":", true, 2);
			tags[tag_value[0]] = tag_value[1];
			
		else:
			# [min:sec.xxx] lyric
			var time_lyric := value_line.split(" ", true, 2);
			
			var time_string := time_lyric[0];
			if !time_string.begins_with("[") or !time_string.ends_with("]"): continue;
			time_string = time_string.substr(1, time_string.length()-2);
			var time := 0.0;
			var min_sec := time_string.split(":", true, 2);
			if min_sec[0].is_valid_int(): time += min_sec[0].to_int() * 60.0;
			if min_sec[1].is_valid_float(): time += min_sec[1].to_float();
			
			lyrics.append([time, time_lyric[1]]);
	
	loaded = true;
