extends SceneTree
func _init():
	var f=FileAccess.open("res://licenses/GODOT_THIRD_PARTY_LICENSES.txt",FileAccess.WRITE)
	for entry in Engine.get_copyright_info():
		f.store_line(str(entry.name))
		for part in entry.parts:
			for copyright in part.copyright: f.store_line(str(copyright))
			f.store_line("License: "+str(part.license))
		f.store_line("")
	var info=Engine.get_license_info()
	for name in info:
		f.store_line("\n=== "+name+" ===\n")
		f.store_line(info[name])
	f.close()
	print("Bundled Godot engine third-party license notices")
	quit()
