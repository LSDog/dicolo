extends TextureRect

## 测试 github REST api 来获取github上的铺面

var tls_client;

func _ready():
	return; # 测试记得删这行
	_ready_later.call_deferred();
	
func _ready_later():
	
	tls_client = TLSOptions.client();
	
	var search_text := "dicolo-map-";
	print("1. search for dicolo map: dicolo-map-")
	print("GET \"https://api.github.com/search/repositories?q=dicolo-map-\"");
	var result = get_text("https://api.github.com", "/search/repositories?q=" + search_text.uri_encode())
	var json :Dictionary = JSON.parse_string(result);
	var result_items :Array = json["items"];
	print("RESULT count: ", json["total_count"]);
	for item in result_items:
		print(
			"""
			name: %s
			author: %s
			update: %s
			description: %s
			link: %s
			trees_url: %s
			default_branch: %s
			"""
			% [
				item['name'],
				item['owner']['login'],
				item['updated_at'],
				item['description'],
				item['html_url'],
				item['trees_url'],
				item['default_branch'],
			]
		);
	if result_items.size() == 0: return;
	var result_item = result_items[0];
	
	print("2. Get file")
	
	print(JSON.parse_string(get_text("https://api.github.com",
		"/repos/%s/%s/contents?ref=master" %
			[result_item['owner']['login'], result_item['name']]
	)));
	
	var file_temp := FileAccess.open("user://temp_%d.jpeg" % hash(self), FileAccess.WRITE);
	file_temp.close();
	
	var url = "https://raw.githubusercontent.com/LSDogX/dicolo-map-HareHareYukai/master/bg.jpeg";
	var http := HTTPRequest.new();
	add_child(http);
	http.download_file = file_temp.get_path_absolute();
	#http.use_threads = true;
	http.set_tls_options(tls_client);
	var header := ["Accept: */*"];
	
	var timer = Timer.new();
	add_child(timer);
	timer.timeout.connect(func():
		print("downloading... status:", http.get_http_client_status());
		print("download: ", http.get_downloaded_bytes(), " / ", http.get_body_size());
	);
	timer.start(0.1);
	
	var err = http.request(url, header);
	print("error = ", err, " - ", error_string(err));
	assert(err == OK);
	
	
	http.request_completed.connect(func(
		result, response_code, headers: PackedStringArray, body):
		
		timer.stop();
		print("Success!  ", http.get_downloaded_bytes(), " / ", http.get_body_size());
		print("""
		result: %s
		response_code: %s
		headers: %s
		body: %s
		""" % [result, response_code, str(headers), str(body)])
		
		var headers_dic = {};
		for text in headers:
			var split = text.split(": ", true, 2);
			headers_dic[split[0]] = split[1];
		
		print("Loading image");
		var image = Image.new();
		image.load(file_temp.get_path_absolute());
		var image_texture = ImageTexture.create_from_image(image);
		texture = image_texture;
		DirAccess.remove_absolute(file_temp.get_path_absolute());
	);
	

func get_text(host: String, url: String) -> String:
	
	var text = null;
	
	var err := 0;
	var http := HTTPClient.new();
	#var tls_client = TLSOptions.client();
	
	err = http.connect_to_host(host, 443, tls_client);
	assert(err == OK);
	
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll();
		#print("Connecting...");
		OS.delay_msec(500);
	print("status = ", http.get_status())
	assert(http.get_status() == HTTPClient.STATUS_CONNECTED);
	
	var headers = [
		#"Aser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.51",
		#"cookie: _octo=GH1.1.168169920.1676175797; logged_in=yes; dotcom_user=LSDogX; fileTreeExpanded=false; color_mode=%7B%22color_mode%22%3A%22dark%22%2C%22light_theme%22%3A%7B%22name%22%3A%22light%22%2C%22color_mode%22%3A%22light%22%7D%2C%22dark_theme%22%3A%7B%22name%22%3A%22dark%22%2C%22color_mode%22%3A%22dark%22%7D%7D; preferred_color_mode=dark; tz=Asia%2FShanghai"
	];
	err = http.request(HTTPClient.METHOD_GET, url, headers);
	assert(err == OK);
	
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll();
		#print("Requesting...");
		OS.delay_msec(500);
	assert(http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED);
	#print("response? ", http.has_response());
	if http.has_response():
		headers = http.get_response_headers_as_dictionary(); # Get response headers.
		#print("code: ", http.get_response_code());
		#print("**headers:\\n", headers);
		if http.is_response_chunked():
			#print("Response is Chunked!");
			pass
		else:
			var bl := http.get_response_body_length();
			#print("Response Length: ", bl);
		var rb := PackedByteArray();
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll();
			var chunk := http.read_response_body_chunk();
			if chunk.size() == 0:
				OS.delay_usec(1000);
			else:
				rb += chunk;
		
		#print("bytes got: ", rb.size());
		text = rb.get_string_from_utf8();
	
	http.close();
	
	return text;
