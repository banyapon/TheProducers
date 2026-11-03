class_name ServiceStatus
extends RefCounted
## Live connectivity checks for Firebase Auth and Cloudinary.
## Connection status only; credentials are not included in the UI or log.

const FIREBASE_URL := "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig?key=%s"
const CLOUDINARY_PING := "https://api.cloudinary.com/v1_1/%s/ping"

## service -> "checking" | "ok" | "error: ..." | "not configured"
static var results := {}
static var _running := false


static func check_all(owner: Node) -> void:
	if _running or not results.is_empty(): return
	_running = true
	results = {"firebase": "checking", "cloudinary": "checking"}
	results["firebase"] = await _firebase(owner)
	results["cloudinary"] = await _cloudinary(owner)
	_running = false
	print("[services] Google Firebase %s | Cloudinary %s" % [
		"Connect!" if results["firebase"] == "ok" else "Failed!",
		"Connect!" if results["cloudinary"] == "ok" else "Failed!"])


static func _firebase(owner: Node) -> String:
	if not Secrets.has_firebase(): return "not configured"
	var res: Dictionary = await Http.fetch(owner, FIREBASE_URL % Secrets.firebase_api_key, 15.0)
	if res["code"] == 200 and Http.json_of(res).has("projectId"): return "ok"
	return "error: " + (res["error"] if res["error"] != "" else "HTTP %d" % res["code"])


static func _cloudinary(owner: Node) -> String:
	if not Cloudinary.is_configured(): return "not configured"
	if Secrets.signing_mode == "server" or Secrets.cloudinary_secret == "":
		return "ok" # server signing: credentials live in the Cloud Function, not in the game
	var auth := Marshalls.utf8_to_base64("%s:%s" % [Secrets.cloudinary_key, Secrets.cloudinary_secret])
	var res: Dictionary = await Http._send(owner, CLOUDINARY_PING % Secrets.cloudinary_cloud,
		PackedStringArray(["Authorization: Basic " + auth]), HTTPClient.METHOD_GET, PackedByteArray(), 15.0)
	if res["code"] == 200 and Http.json_of(res).get("status", "") == "ok": return "ok"
	return "error: " + (res["error"] if res["error"] != "" else "HTTP %d" % res["code"])
