class_name GoogleDesktop
extends RefCounted
## Desktop OAuth uses the system browser, PKCE and a loopback-only listener.
## No account is opened automatically by the game or its tests.

static func config() -> Dictionary:
	var cfg = ConfigFile.new()
	for path in Secrets.PATHS:
		if cfg.load(path) == OK:
			return {"client_id": str(cfg.get_value("google", "client_id", "")), "client_secret": str(cfg.get_value("google", "client_secret", ""))}
	return {"client_id": "", "client_secret": ""}

static func form(values: Dictionary) -> String:
	var parts = PackedStringArray()
	for key in values:
		parts.append(str(key).uri_encode() + "=" + str(values[key]).uri_encode())
	return "&".join(parts)

static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

static func callback_query(request: String, expected_state: String) -> Dictionary:
	var first_line = request.get_slice("\r\n", 0).split(" ")
	if first_line.size() < 2 or first_line[0] != "GET": return {}
	var target: String = first_line[1]
	if not target.begins_with("/?"): return {}
	var query: Dictionary = {}
	for pair in target.get_slice("?", 1).split("&"):
		query[pair.get_slice("=", 0).uri_decode()] = pair.get_slice("=", 1).replace("+", " ").uri_decode()
	if str(query.get("state", "")) != expected_state: return {}
	return query

static func authorize(owner_node: Node) -> Dictionary:
	var settings = config()
	if str(settings["client_id"]).is_empty(): return {"error": "configuration"}
	var crypto = Crypto.new()
	var verifier = base64url(crypto.generate_random_bytes(32))
	var state = base64url(crypto.generate_random_bytes(24))
	var listener = TCPServer.new()
	var port = 0
	for attempt in 8:
		port = randi_range(49152, 65535)
		if listener.listen(port, "127.0.0.1") == OK: break
	if not listener.is_listening(): return {"error": "listener"}
	var redirect = "http://127.0.0.1:%d/" % port
	var url = "https://accounts.google.com/o/oauth2/v2/auth?" + form({"client_id": settings["client_id"], "redirect_uri": redirect, "response_type": "code", "scope": "openid email", "state": state, "code_challenge": base64url(verifier.sha256_buffer()), "code_challenge_method": "S256", "prompt": "select_account"})
	if OS.shell_open(url) != OK:
		listener.stop()
		return {"error": "browser"}
	var deadline = Time.get_ticks_msec() + 180000
	var query: Dictionary = {}
	while Time.get_ticks_msec() < deadline and not owner_node._google_cancelled:
		if listener.is_connection_available():
			var connection = listener.take_connection()
			var buffer = PackedByteArray()
			var connection_deadline = mini(deadline, Time.get_ticks_msec() + 5000)
			while Time.get_ticks_msec() < connection_deadline and not owner_node._google_cancelled:
				connection.poll()
				if connection.get_available_bytes() > 0:
					var chunk = connection.get_data(connection.get_available_bytes())
					if chunk[0] != OK: break
					buffer.append_array(chunk[1])
					if buffer.size() > 8192: break
					if buffer.get_string_from_utf8().contains("\r\n\r\n"):
						query = callback_query(buffer.get_string_from_utf8(), state)
						break
				await owner_node.get_tree().create_timer(0.05).timeout
			var message = "<html><body style='background:#121e31;color:#ffebbe;font-family:monospace;padding:48px'>The Producer!<br><br>Sign-in response received. Return to the game.</body></html>"
			var response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s" % [message.to_utf8_buffer().size(), message]
			connection.put_data(response.to_utf8_buffer())
			connection.disconnect_from_host()
			if not query.is_empty(): break
		await owner_node.get_tree().create_timer(0.05).timeout
	listener.stop()
	if query.is_empty() or query.has("error") or owner_node._google_cancelled:
		return {"error": "cancelled"}
	var token_form = {"client_id": settings["client_id"], "code": query.get("code", ""), "code_verifier": verifier, "redirect_uri": redirect, "grant_type": "authorization_code"}
	if not str(settings["client_secret"]).is_empty(): token_form["client_secret"] = settings["client_secret"]
	var response = await Http.post(owner_node, "https://oauth2.googleapis.com/token", PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), form(token_form).to_utf8_buffer(), 25.0)
	var data = Http.json_of(response)
	if response["code"] != 200 or not data.has("id_token"): return {"error": "token"}
	return {"id_token": data["id_token"], "redirect_uri": redirect}
