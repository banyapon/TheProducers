extends Node
## Signed uploads to Cloudinary (multipart/form-data).
## signing_mode "local":  SHA-1 signature computed in-game (dev only — the api_secret ships with the build).
## signing_mode "server": the Firebase Cloud Function in server/ signs, authenticated by the player's ID token.

const UPLOAD_URL := "https://api.cloudinary.com/v1_1/%s/%s/upload"


func is_configured() -> bool:
	if Secrets.cloudinary_cloud == "":
		return false
	if Secrets.signing_mode == "server":
		return Secrets.signing_url != ""
	return Secrets.cloudinary_key != "" and Secrets.cloudinary_secret != ""


## resource_type: "image" for covers, "video" for audio (Cloudinary stores audio as video).
## Returns Cloudinary's JSON (secure_url, public_id, ...) or {"error": message}.
func upload(bytes: PackedByteArray, filename: String, mime: String, resource_type: String,
		folder: String, public_id: String, tags: Array = []) -> Dictionary:
	var params = {
		"folder": folder,
		"public_id": public_id,
		"timestamp": str(int(Time.get_unix_time_from_system())),
	}
	if not tags.is_empty():
		params["tags"] = ",".join(PackedStringArray(tags))
	var auth: Dictionary = await _sign(params)
	if auth.has("error"):
		return auth
	var fields = params.duplicate()
	fields["api_key"] = auth["api_key"]
	fields["signature"] = auth["signature"]
	var boundary = "TheProducers%d" % Time.get_ticks_usec()
	var res: Dictionary = await Http.post(self, UPLOAD_URL % [Secrets.cloudinary_cloud, resource_type],
		PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary]),
		_multipart(boundary, fields, bytes, filename, mime), 180.0)
	var data = Http.json_of(res)
	if res["code"] == 200:
		return data
	var message: String = data.get("error", {}).get("message", res["error"] if res["error"] != "" else "HTTP %d" % res["code"])
	return {"error": message}


## Cloudinary signature: sha1("k1=v1&k2=v2..." sorted by key + api_secret).
static func sign_params(params: Dictionary, secret: String) -> String:
	var keys = params.keys()
	keys.sort()
	var pairs = PackedStringArray()
	for key in keys:
		pairs.append("%s=%s" % [key, params[key]])
	return ("&".join(pairs) + secret).sha1_text()


## Audio uploaded in any format can be streamed as MP3 by swapping the extension.
static func mp3_url(secure_url: String) -> String:
	return secure_url.get_basename() + ".mp3"


func _sign(params: Dictionary, operation: String = "upload") -> Dictionary:
	if Secrets.signing_mode != "server":
		return {"signature": sign_params(params, Secrets.cloudinary_secret), "api_key": Secrets.cloudinary_key}
	var token: String = await FirebaseAuth.get_id_token()
	if token == "":
		return {"error": Locale.text("legacy_000")}
	var res: Dictionary = await Http.post(self, Secrets.signing_url,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + token]),
		JSON.stringify({"params": params, "operation": operation}).to_utf8_buffer(), 20.0)
	var data = Http.json_of(res)
	if res["code"] != 200 or not data.has("signature"):
		return {"error": Locale.text("legacy_001") % data.get("error", "HTTP %d" % res["code"])}
	return {"signature": data["signature"], "api_key": data["api_key"]}

func destroy(public_id: String, resource_type: String) -> Dictionary:
	if not FirebaseAuth.is_signed_in() or not is_configured(): return {"error": "Connection required"}
	var prefix = Secrets.cloudinary_root + "/" + FirebaseAuth.uid + "/"
	if not public_id.begins_with(prefix) or ".." in public_id or resource_type not in ["image", "video", "raw"]:
		return {"error": "Invalid asset owner"}
	var params = {"public_id": public_id, "timestamp": str(int(Time.get_unix_time_from_system())), "invalidate": "true"}
	var auth = await _sign(params, "destroy")
	if auth.has("error"): return auth
	var fields = params.duplicate()
	fields["api_key"] = auth["api_key"]
	fields["signature"] = auth["signature"]
	var pairs = PackedStringArray()
	for key in fields: pairs.append(str(key).uri_encode() + "=" + str(fields[key]).uri_encode())
	var response = await Http.post(self, "https://api.cloudinary.com/v1_1/%s/%s/destroy" % [Secrets.cloudinary_cloud, resource_type], PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), "&".join(pairs).to_utf8_buffer(), 30.0)
	var data = Http.json_of(response)
	if response["code"] == 200 and data.get("result", "") in ["ok", "not found"]: return {"ok": true}
	return {"error": "Failed!"}


func _multipart(boundary: String, fields: Dictionary, file_bytes: PackedByteArray, filename: String, mime: String) -> PackedByteArray:
	var body = PackedByteArray()
	for key in fields:
		body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, key, fields[key]]).to_utf8_buffer())
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [boundary, filename, mime]).to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	return body
