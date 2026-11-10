extends SceneTree
## Exercise the actual Godot Vorbis decoder/loop_offset for 15 min per stream.
## Offline mix at normal rate; not a claim of subjective listening.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var music=root.get_node("MusicManager")
	while music.streams.size()<6:await process_frame
	music.set_process(false)
	var report:Array=[]
	var failed:=false
	var rate:=int(AudioServer.get_mix_rate())
	for id in music.streams:
		var stream:AudioStreamOggVorbis=music.streams[id]
		var playback:=stream.instantiate_playback()
		playback.start()
		var total:=0
		var silent_run:=0
		var max_silent:=0
		var peak:=0.0
		var previous:Array[PackedVector2Array]=[]
		var capture:FileAccess
		var following:=0
		var recorded:=false
		var loops:=0
		var last_position:=0.0
		while total<rate*900:
			var chunk:=playback.mix_audio(1.0,rate/10)
			if chunk.is_empty():failed=true;break
			var position:=playback.get_playback_position()
			if position<last_position-1:
				loops+=1
				if not recorded:
					capture=FileAccess.open("res://reports/evidence/p07v03-music/audio/godot-"+id+"-seam.f32",FileAccess.WRITE)
					for buffer in previous:capture.store_buffer(buffer.to_byte_array())
					following=30;recorded=true
			last_position=position
			if following>0:
				capture.store_buffer(chunk.to_byte_array());following-=1
				if following==0:capture.close()
			previous.append(chunk)
			if previous.size()>10:previous.pop_front()
			var block_peak:=0.0
			for i in range(0,chunk.size(),64):block_peak=maxf(block_peak,maxf(absf(chunk[i].x),absf(chunk[i].y)))
			peak=maxf(peak,block_peak)
			silent_run=silent_run+1 if block_peak<0.0001 else 0
			max_silent=maxi(max_silent,silent_run)
			total+=chunk.size()
			if total%(rate*30)==0:await process_frame
		var expected:=int(floor((900-stream.get_length())/(stream.get_length()-stream.loop_offset)))+1
		var ok:=loops==expected and playback.is_playing() and max_silent<=2
		failed=failed or not ok
		report.append({"id":id,"seconds":float(total)/rate,"loops":loops,"expected":expected,"playing":playback.is_playing(),"max_silence_seconds":max_silent*.1,"peak":peak,"rate":rate,"passed":ok,"loop_start":stream.loop_offset})
		print("SOAK ",id," ",report[-1])
		playback.stop()
	FileAccess.open("res://reports/evidence/p07v03-music/audio/godot-soak.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	music.stop_all()
	OS.delay_msec(150)
	quit(1 if failed else 0)
