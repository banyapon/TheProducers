extends Node
## Live check of Firebase Auth (anonymous) + signed Cloudinary upload using config/secrets.cfg:
##   godot --headless --path . res://tests/net_test.tscn


func _ready() -> void:
	FirebaseAuth.auth_error.connect(func(m): print("  auth_error: ", m))
	var ok: bool = await FirebaseAuth.sign_in_anonymous()
	print("firebase anonymous sign-in: ", ok, "  uid=", FirebaseAuth.uid)
	if not ok:
		get_tree().quit(1)
		return
	var img := CoverArt.generate([Color.HOT_PINK, Color.CYAN], 42)
	var res: Dictionary = await Cloudinary.upload(img.save_png_to_buffer(), "connection_test.png", "image/png", "image",
		"%s/%s/covers" % [Secrets.cloudinary_root, FirebaseAuth.uid], "connection_test", ["the_producers"])
	print("cloudinary upload: ", res.get("secure_url", res.get("error", res)))
	get_tree().quit(0 if res.has("secure_url") else 1)
