class_name GoogleWeb
extends RefCounted

static func client_id() -> String:
	var cfg = ConfigFile.new()
	for path in ["res://config/public.cfg", "user://secrets.cfg", "res://config/secrets.cfg"]:
		if cfg.load(path) == OK:
			var value = str(cfg.get_value("google", "web_client_id", ""))
			if not value.is_empty(): return value
	return ""

static func authorize(owner_node: Node) -> Dictionary:
	if not OS.has_feature("web") or client_id().is_empty(): return {"error": "configuration"}
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/net/google_web.js"), true)
	JavaScriptBridge.eval("window.producerGoogle.open(" + JSON.stringify(client_id()) + ")", true)
	var deadline = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and not owner_node._google_cancelled:
		var result = str(JavaScriptBridge.eval("JSON.stringify(window.producerGoogle.result)", true))
		if result != "null":
			JavaScriptBridge.eval("window.producerGoogle.close()", true)
			var parsed = JSON.parse_string(result)
			return parsed if parsed is Dictionary else {"error": "browser"}
		await owner_node.get_tree().create_timer(0.1).timeout
	JavaScriptBridge.eval("window.producerGoogle.close()", true)
	return {"error": "cancelled"}
