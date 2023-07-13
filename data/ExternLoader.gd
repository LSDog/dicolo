# Originally from:
# GDScriptAudioImport v0.1
# https://github.com/towai/GDScriptAudioImport/blob/master/GDScriptAudioImport.gd
# MIT License Copyright (c) 2020 Gianclgar (Giannino Clemente) gianclgar@gmail.com

class_name ExternLoader

enum {
	HDR_RIFF = 0x01,
	HDR_WAVE = 0x02,
	HDR_FMT  = 0x04,
	HDR_DATA = 0x08,
}

static func report_errors(err, path):
	var result_hash = error_string(err)
	if result_hash != "":
		print("Error: ", result_hash, " ", path)
	else:
		print("Unknown error with file ", path, " error code: ", str(err))

static func load_image(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return ResourceLoader.load(path, "Texture2D");
	var image = Image.new();
	var err = image.load(path);
	if err != OK: report_errors(err, path);
	return ImageTexture.create_from_image(image);

static func load_audio(path: String, loop: bool = false) -> AudioStream:
	if path.begins_with("res://"):
		return ResourceLoader.load(path, "AudioStream");
	var file = FileAccess.open(path, FileAccess.READ)
	var err = FileAccess.get_open_error()
	if err != OK:
		report_errors(err, path)
		return AudioStream.new()

	var bytes = file.get_buffer(file.get_length())
	var headers_parsed := 0
	# if File is wav
	if path.ends_with(".wav"):
		var newstream = AudioStreamWAV.new()
		
		#---------------------------
		#parrrrseeeeee!!! :D
		
		var bits_per_sample = 0
		var loops := []
		print("File is %d bytes long" % bytes.size())
		
		var i := 0
		while i < (bytes.size() - 3):
			var those4bytes = str(char(bytes[i]) + char(bytes[i + 1]) \
					+ char(bytes[i + 2]) + char(bytes[i + 3]))
			
			if those4bytes == "RIFF": 
				print ("RIFF OK at bytes " + str(i) + "-" + str(i + 3))
				headers_parsed += HDR_RIFF
				i += 4
				#RIP bytes 4-7 integer for now
			elif those4bytes == "WAVE": 
				print ("WAVE OK at bytes " + str(i) + "-" + str(i + 3))
				headers_parsed += HDR_WAVE
				i += 1

			elif those4bytes == "fmt ":
				print ("fmt OK at bytes " + str(i) + "-" + str(i + 3))
				
				#get format subchunk size, 4 bytes next to "fmt " are an int32
				var formatsubchunksize = bytes.decode_u32(i + 4)
				print ("Format subchunk size: " + str(formatsubchunksize))
				
				#using formatsubchunk index so it's easier to understand what's going on
				var fsc0 = i + 8 #fsc0 is byte 8 after start of "fmt "

				#get format code [Bytes 0-1]
				var format_code = bytes.decode_u16(fsc0)
				var format_name
				if format_code == 0: format_name = "8_BITS"
				elif format_code == 1: format_name = "16_BITS"
				elif format_code == 2: format_name = "IMA_ADPCM"
				else: 
					format_name = "UNKNOWN (trying to interpret as 16_BITS)"
					format_code = 1
				print ("Format: " + str(format_code) + " " + format_name)
				#assign format to our AudioStreamSample
				newstream.format = format_code
				
				#get channel num [Bytes 2-3]
				var channel_num = bytes.decode_u16(fsc0 + 2)
				print ("Number of channels: " + str(channel_num))
				#set our AudioStreamSample to stereo if needed
				if channel_num == 2: newstream.stereo = true
				
				var sample_rate = bytes.decode_u32(fsc0 + 4)
				print ("Sample rate: " + str(sample_rate))
				newstream.mix_rate = sample_rate
				
				#get byte_rate [Bytes 8-11] because we can
				var byte_rate = bytes.decode_u32(fsc0 + 8)
				print ("Byte rate: " + str(byte_rate))
				
				#same with bits*sample*channel [Bytes 12-13]
				var bits_sample_channel = bytes.decode_u16(fsc0 + 12)
				print ("BitsPerSample * Channel / 8: " + str(bits_sample_channel))
				
				#aaaand bits per sample/bitrate [Bytes 14-15]
				bits_per_sample = bytes.decode_u16(fsc0 + 14)
				print ("Bits per sample: " + str(bits_per_sample))
				headers_parsed += HDR_FMT
				i = fsc0 + 16
			
			elif those4bytes == "data":
				assert(bits_per_sample != 0)
				
				var audio_data_size = bytes.decode_u32(i + 4)
				print ("Audio data/stream size is " + str(audio_data_size) + " bytes")

				var data_entry_point = (i + 8)
				print ("Audio data starts at byte " + str(data_entry_point))
				
				var data = bytes.slice(data_entry_point, data_entry_point + audio_data_size)
				
				if bits_per_sample in [24, 32]:
					newstream.data = convert_to_16bit(data, bits_per_sample)
				else:
					newstream.data = data
#				headers_parsed += HDR_DATA
				# no need to check the sample data for headers
				i = data_entry_point + audio_data_size

			# Parse Sampler chunk
			
			elif those4bytes == "smpl":
				i += 4
				var chunk_size = bytes.decode_u32(i)
				i += 4
				print("Sampler chunk of size %d found @ %d" % [chunk_size, i])
				
				# skip:
				#  long           dwManufacturer;
				#  long           dwProduct;
				#  long           dwSamplePeriod;
				i += 12
				
				var dw_midi_unity_note = bytes.decode_u32(i)
				i += 4
				
				var uint32_max = 4_294_967_295
				var dw_midi_pitch_fraction = bytes.decode_u32(i)
				i += 4
				print("Sample stored at %f up from MIDI note %d" % [
						float(dw_midi_pitch_fraction) / uint32_max,
						dw_midi_unity_note
						])
				
				# skip:
				#  long           dwSMPTEFormat;
				#  long           dwSMPTEOffset;
				i += 8
				
				var sample_loops_remaining = bytes.decode_u32(i)
				var sampler_data = bytes.decode_u32(i + 4)
				i += 8
				print("contains %d loops -- %d of additional data before loops[]" 
						% [sample_loops_remaining, sampler_data])
				
				while sample_loops_remaining:
					var sample_loop := {}
					sample_loop["identifier"] = bytes.decode_u32(i)
					sample_loop["type"] 	= bytes.decode_u32(i + 4)
					sample_loop["start"]	= bytes.decode_u32(i + 8)
					sample_loop["end"]		= bytes.decode_u32(i + 12)
					i += 16
					print("Parsed loop: id: %d\t type: %d\t start: %d\t end: %d" % [
							sample_loop["identifier"], sample_loop["type"],
							sample_loop["start"], sample_loop["end"]
							])
					# throw away dwFraction & dwPlayCount
					i += 8
					loops.append(sample_loop)
					sample_loops_remaining -= 1
			
			else: i += 1
			# end of parsing
			#---------------------------
		
		if !loops.is_empty():
			var sample_loop : Dictionary = loops[0]
			newstream.loop_begin = sample_loop["start"]
			newstream.loop_end = sample_loop["end"]
			if loop: match sample_loop["type"]:
				0: newstream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				1: newstream.loop_mode = AudioStreamWAV.LOOP_PINGPONG
				2: newstream.loop_mode = AudioStreamWAV.LOOP_BACKWARD
				_: print("Unknown loop type %d")

		return newstream  # :D

	# disabled to return an empty stream as 4.0, for now, does not support runtime loading of oggs
	# https://github.com/godotengine/godot/issues/61091
	# some programs use .logg to identify looping oggs
	elif path.ends_with(".ogg") || path.ends_with(".logg"):
		var newstream = AudioStreamOggVorbis.new()
#		newstream.loop = loop
#		newstream.data = bytes
		print("can't do that for you chief!")
		return newstream

	#if file is mp3
	elif path.ends_with(".mp3"):
		var newstream = AudioStreamMP3.new()
		newstream.loop = loop
		newstream.data = bytes
		return newstream

	else:
		print ("ERROR: Wrong filetype or format")
		return AudioStream.new()
	

# Converts .wav data from 24 or 32 bits to 16
#
# These conversions are SLOW in GDScript
# on my one test song, 32 -> 16 was around 3x slower than 24 -> 16
#
# I couldn't get threads to help very much
# They made the 24bit case about 2x faster in my test file
# And the 32bit case abour 50% slower
# I don't wanna risk it always being slower on other files
# And really, the solution would be to handle it in a low-level language
static func convert_to_16bit(data: PackedByteArray, from: int) -> PackedByteArray:
	print("converting to 16-bit from %d" % from)
	var time = Time.get_ticks_msec()
	# 24 bit .wav's are typically stored as integers
	# so we just grab the 2 most significant bytes and ignore the other
	if from == 24:
		var j = 0
		for i in range(0, data.size(), 3):
			data[j] = data[i+1]
			data[j+1] = data[i+2]
			j += 2
		data.resize(data.size() * 2 / 3)
	# 32 bit .wav's are typically stored as floating point numbers
	# so we need to grab all 4 bytes and interpret them as a float first
	if from == 32:
		var spb := StreamPeerBuffer.new()
		var single_float: float
		var value: int
		for i in range(0, data.size(), 4):
			spb.data_array = data.slice(i, i+4)
			single_float = spb.get_float()
			value = single_float * 32768
			data[i/2] = value
			data[i/2+1] = value >> 8
		data.resize(data.size() / 2)
	print("Took %f seconds for slow conversion" % ((Time.get_ticks_msec() - time) / 1000.0))
	return data


# ---------- REFERENCE ---------------
# note: typical values doesn't always match

#Positions  Typical Value Description
#
#1 - 4      "RIFF"        Marks the file as a RIFF multimedia file.
#                         Characters are each 1 byte long.
#
#5 - 8      (integer)     The overall file size in bytes (32-bit integer)
#                         minus 8 bytes. Typically, you'd fill this in after
#                         file creation is complete.
#
#9 - 12     "WAVE"        RIFF file format header. For our purposes, it
#                         always equals "WAVE".
#
#13-16      "fmt "        Format sub-chunk marker. Includes trailing null.
#
#17-20      16            Length of the rest of the format sub-chunk below.
#
#21-22      1             Audio format code, a 2 byte (16 bit) integer. 
#                         1 = PCM (pulse code modulation).
#
#23-24      2             Number of channels as a 2 byte (16 bit) integer.
#                         1 = mono, 2 = stereo, etc.
#
#25-28      44100         Sample rate as a 4 byte (32 bit) integer. Common
#                         values are 44100 (CD), 48000 (DAT). Sample rate =
#                         number of samples per second, or Hertz.
#
#29-32      176400        (SampleRate * BitsPerSample * Channels) / 8
#                         This is the Byte rate.
#
#33-34      4             (BitsPerSample * Channels) / 8
#                         1 = 8 bit mono, 2 = 8 bit stereo or 16 bit mono, 4
#                         = 16 bit stereo.
#
#35-36      16            Bits per sample. 
#
#37-40      "data"        Data sub-chunk header. Marks the beginning of the
#                         raw data section.
#
#41-44      (integer)     The number of bytes of the data section below this
#                         point. Also equal to (#ofSamples * #ofChannels *
#                         BitsPerSample) / 8
#
#45+                      The raw audio data.            
