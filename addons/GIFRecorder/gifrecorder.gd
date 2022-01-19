tool
# Intern initializations
extends ReferenceRect # Extends from ReferenceRect

# load gif exporter module
onready var gifexporter = preload("res://addons/GIFRecorder/gdgifexporter/gifexporter.gd")
# load and initialize quantization method that you want to use
onready var median_cut = preload("res://addons/GIFRecorder/gdgifexporter/quantization/median_cut.gd").new()
onready var enhanced_uniform_quantizator = preload("res://addons/GIFRecorder/gdgifexporter/quantization/enhanced_uniform_quantization.gd").new()

onready var _export_thread = Thread.new()

# ======================================================

const RECORD_KEY = KEY_F1 # Change this to the key you want to start/stop recording the frames.
const SAVE_KEY = KEY_F2 # Change this to the key you want to save the frames recorded.
const EXPORT_KEY = KEY_F3

# Export variables!
export(float) var frames_per_second = 15.0
export(String) var output_folder = "out"
export(bool) var flip_y = true
export(bool) var use_thread = false # so the game wont freeze while the frames are being saved

# Intern variables
onready var _frametick = 1.0/frames_per_second
onready var _images = []
onready var _running = false
onready var _viewport = get_viewport()
onready var _label = Label.new()

onready var _thread = Thread.new()

# ======================================================

func _ready():
	# If running on editor, DONT override process and input
	set_process(false)
	set_process_input(false)
	
	if not Engine.editor_hint:
		set_process(true)
		set_process_input(true)
		
		# Some recorder info to show onscreen
		get_viewport().call_deferred("add_child", _label)
#		print(get_tree().root)
#		get_tree().root.add_child(_label)
		_label.text = "Waiting for capture...\nNumber of frames recorded: " + str(_images.size())

func _input(event):
	if event is InputEventKey and event.pressed and !event.echo:
		if event.scancode == RECORD_KEY:
			if (_thread.is_active()):
				return
			_running = !_running
			_label.hide()
			if (not _running): # It was running before
				_label.show()
				_label.text = "Waiting for capture...\nNumber of frames recorded: " + str(_images.size())
		if event.scancode == SAVE_KEY and not _running:
			if (use_thread):
				if(not _thread.is_active()):
					var err = _thread.start(self, "save_frames")
			else:
				save_frames(null)
		if event.scancode == EXPORT_KEY and not _running:
			if (_export_thread.is_active()):
				return
			if (use_thread):
				if(not _export_thread.is_active()):
					var err = _export_thread.start(self, "export_gif")
			else:
				export_gif(null)

func _process(delta):
	# Get images
	if _running:
		_frametick += delta
		if (_frametick > 1.0/frames_per_second):
			_frametick -= 1.0/frames_per_second
			# Retrieve viewport texture
			var image = _viewport.get_texture().get_data()
			# Get the recorder frame section out of it
			var pos = get_global_transform_with_canvas().origin
			var rect = Rect2(Vector2(pos.x,_viewport.size.y - (pos.y + get_rect().size.y)), get_rect().size)
			image.blit_rect(image, rect, Vector2(0,0))
			_images.append(image)
			
func _exit_tree():
	if(_thread.is_active()):
		_thread.wait_to_finish()
		
	if(_export_thread.is_active()):
		_export_thread.wait_to_finish()
		
func save_frames(userdata):
	# userdata wont be used, is just for the thread calling
	var dir = Directory.new()
	dir.make_dir(output_folder)
	if dir.open("res://" + output_folder + "/") != OK:
		print("An error occurred when trying to create the output folder.")
	
	var i = 0
	for image in _images:
		print("saving")
		_label.text = "Saving frames...("+str(i) + "/"+str(_images.size())+")"
		image.crop(self.get_rect().size.x, self.get_rect().size.y)
		if (flip_y):
			image.flip_y()
		#image.save_png("res://" + str(output_folder) + "/" + "%03d" % i + ".png")
		i+=1
	_label.text = "Done! Check the "+output_folder+" folder on your project."

func export_gif(userdata):
	# userdata wont be used, is just for the thread calling
	var exporter = gifexporter.new(get_rect().size.x, get_rect().size.y)
	
	var dir = Directory.new()
	dir.make_dir(output_folder)
	if dir.open("res://" + output_folder + "/") != OK:
		print("An error occurred when trying to create the output folder.")
	
	var i = 0
	for image in _images:
		print("exporting")
		i+=1
		image.convert(Image.FORMAT_RGBA8)
		exporter.write_frame(image, i, enhanced_uniform_quantizator)
	_images.clear()
	
	var file = File.new()
	file.open("res://" + str(output_folder) + "/" + "result.gif", File.WRITE)
	file.store_buffer(exporter.export_file_data())
	file.close()
