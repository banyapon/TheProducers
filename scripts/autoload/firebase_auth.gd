extends Node
## Firebase Authentication over the REST API (email/password + anonymous "Guest").
## The refresh token is kept in user:// so players stay signed in between sessions.

signal signed_in(user: Dictionary)
signal signed_out
signal auth_error(message: String)

const ACCOUNT_URL := "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s"
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const SESSION_PATH := "user://auth_session.cfg"
var ERRORS = {
	"EMAIL_EXISTS": Locale.text("legacy_081"),
	"EMAIL_NOT_FOUND": Locale.text("legacy_082"),
	"INVALID_PASSWORD": Locale.text("legacy_083"),
	"INVALID_LOGIN_CREDENTIALS": Locale.text("legacy_084"),
	"INVALID_EMAIL": Locale.text("legacy_085"),
	"MISSING_PASSWORD": Locale.text("legacy_086"),
	"WEAK_PASSWORD": Locale.text("legacy_087"),
	"OPERATION_NOT_ALLOWED": Locale.text("legacy_088"),
	"ADMIN_ONLY_OPERATION": Locale.text("legacy_089"),
	"TOO_MANY_ATTEMPTS_TRY_LATER": Locale.text("legacy_090"),
	"CONFIGURATION_NOT_FOUND": Locale.text("legacy_091"),
	"TOKEN_EXPIRED": Locale.text("legacy_092"),
	"INVALID_REFRESH_TOKEN": Locale.text("legacy_092"),
}

var uid = ""
var email = ""
var is_anonymous = false
var _id_token = ""
var _refresh_token = ""
var _expires_at = 0.0
var google_busy := false
var _google_cancelled := false

func has_google() -> bool:
	if OS.has_feature("web"): return Secrets.has_firebase() and not GoogleWeb.client_id().is_empty()
	return Secrets.has_firebase() and not str(GoogleDesktop.config()["client_id"]).is_empty()

func cancel_google() -> void:
	_google_cancelled = true

func sign_in_google() -> bool:
	if google_busy or not has_google():
		auth_error.emit(Locale.text("google_setup"))
		return false
	google_busy = true
	_google_cancelled = false
	var result = await GoogleWeb.authorize(self) if OS.has_feature("web") else await GoogleDesktop.authorize(self)
	google_busy = false
	if result.has("error"):
		auth_error.emit(Locale.text("google_cancelled" if result["error"] == "cancelled" else "google_failed"))
		return false
	return await _account_call("signInWithIdp", {"postBody": "id_token=" + str(result["id_token"]).uri_encode() + "&providerId=google.com", "requestUri": result["redirect_uri"], "returnSecureToken": true, "returnIdpCredential": false})


func is_signed_in() -> bool:
	return uid != ""


func display_name() -> String:
	if uid == "":
		return Locale.text("legacy_093")
	return mask_email(email) if email != "" else "Guest-%s" % uid.left(6)


static func mask_email(value: String) -> String:
	var at = value.rfind("@")
	if at <= 0: return value
	var hidden = maxi(1, ceili(at * 0.4))
	return value.left(at - hidden) + "****" + value.substr(at)


func sign_up(mail: String, password: String) -> bool:
	return await _account_call("signUp", {"email": mail, "password": password, "returnSecureToken": true})


func sign_in(mail: String, password: String) -> bool:
	return await _account_call("signInWithPassword", {"email": mail, "password": password, "returnSecureToken": true})


func sign_in_anonymous() -> bool:
	return await _account_call("signUp", {"returnSecureToken": true})


func has_saved_session() -> bool:
	var cfg = ConfigFile.new()
	return cfg.load(SESSION_PATH) == OK and str(cfg.get_value("auth", "refresh_token", "")) != ""


func saved_session_label() -> String:
	var cfg = ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return ""
	var mail = str(cfg.get_value("auth", "email", ""))
	return mail if mail != "" else "Guest-%s" % str(cfg.get_value("auth", "uid", "")).left(6)


func restore_session() -> bool:
	var cfg = ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return false
	_refresh_token = cfg.get_value("auth", "refresh_token", "")
	email = cfg.get_value("auth", "email", "")
	is_anonymous = cfg.get_value("auth", "anonymous", false)
	if not await _refresh():
		return false
	signed_in.emit(_user_dict())
	return true


## Fresh ID token (refreshes automatically a minute before expiry). Used for the signing server.
func get_id_token() -> String:
	if uid == "":
		return ""
	if Time.get_unix_time_from_system() > _expires_at - 60.0:
		await _refresh()
	return _id_token


func sign_out() -> void:
	uid = ""
	email = ""
	_id_token = ""
	_refresh_token = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	signed_out.emit()


func _account_call(endpoint: String, body: Dictionary) -> bool:
	if not Secrets.has_firebase():
		auth_error.emit(Locale.text("legacy_094"))
		return false
	var res: Dictionary = await Http.post(self, ACCOUNT_URL % [endpoint, Secrets.firebase_api_key],
		PackedStringArray(["Content-Type: application/json"]), JSON.stringify(body).to_utf8_buffer(), 20.0)
	var data = Http.json_of(res)
	if res["code"] != 200:
		auth_error.emit(_error_text(res, data))
		return false
	uid = data.get("localId", "")
	email = data.get("email", "")
	is_anonymous = email == ""
	_id_token = data.get("idToken", "")
	_refresh_token = data.get("refreshToken", "")
	_expires_at = Time.get_unix_time_from_system() + float(data.get("expiresIn", "3600"))
	_save_session()
	signed_in.emit(_user_dict())
	return true


func _refresh() -> bool:
	if _refresh_token == "" or not Secrets.has_firebase():
		return false
	var body = "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var res: Dictionary = await Http.post(self, REFRESH_URL % Secrets.firebase_api_key,
		PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), body.to_utf8_buffer(), 20.0)
	var data = Http.json_of(res)
	if res["code"] != 200:
		auth_error.emit(_error_text(res, data))
		return false
	uid = data.get("user_id", "")
	_id_token = data.get("id_token", "")
	_refresh_token = data.get("refresh_token", _refresh_token)
	_expires_at = Time.get_unix_time_from_system() + float(data.get("expires_in", "3600"))
	_save_session()
	return true


func _save_session() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("auth", "refresh_token", _refresh_token)
	cfg.set_value("auth", "uid", uid)
	cfg.set_value("auth", "email", email)
	cfg.set_value("auth", "anonymous", is_anonymous)
	cfg.save(SESSION_PATH)


func _user_dict() -> Dictionary:
	return {"uid": uid, "email": email, "anonymous": is_anonymous}


func _error_text(res: Dictionary, data: Dictionary) -> String:
	if res["code"] == 0:
		return Locale.text("legacy_095") % res["error"]
	var message = str(data.get("error", {}).get("message", "HTTP %d" % res["code"]))
	var key = message.split(" ")[0]
	if key.begins_with("API_KEY") or message.contains("referer") or message.contains("API key"):
		return Locale.text("legacy_096")
	return Locale.legacy(ERRORS.get(key, message))
