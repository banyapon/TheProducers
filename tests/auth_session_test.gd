extends Node

class MockAuth extends "res://scripts/autoload/firebase_auth.gd":
	var response := {}
	var requests := 0
	var last_body := ""
	func _post(_url: String, _headers: PackedStringArray, body: PackedByteArray, _timeout: float) -> Dictionary:
		requests += 1
		last_body = body.get_string_from_utf8()
		await get_tree().process_frame
		return response

var failures := 0
var pending_token := ""

func check(ok: bool, label: String) -> void:
	if ok: print("ok: ", label)
	else: failures += 1; push_error(label)

func result(code: int, data: Dictionary) -> Dictionary:
	return {"code":code, "body":JSON.stringify(data).to_utf8_buffer(), "error":"test network failure"}

func fetch_token(auth: MockAuth) -> void:
	pending_token = await auth.get_id_token()

func _ready() -> void:
	var original_key = Secrets.firebase_api_key
	Secrets.firebase_api_key = "test-only"
	var auth = MockAuth.new()
	auth.session_path = "user://auth_session_regression_qa.cfg"
	add_child(auth)
	auth.sign_out()
	auth.response = result(200, {"localId":"test-user", "email":"test@example.invalid", "idToken":"test-id", "refreshToken":"test-refresh", "expiresIn":"3600"})
	check(await auth._account_call("signInWithIdp", {}), "Google exchange persists session")
	check(auth.has_saved_session(), "refresh token survives on disk")
	auth.suspend_session()
	check(not auth.is_signed_in() and auth.has_saved_session(), "offline mode forgets active identity but preserves remembered account")
	auth.response = result(200, {"user_id":"test-user", "id_token":"renewed-id", "refresh_token":"rotated-refresh", "expires_in":"3600"})
	check(await auth.restore_session(), "returning player restores without Google authorization")
	check(auth.email == "test@example.invalid" and auth.uid == "test-user", "restore keeps account identity")
	var saved = ConfigFile.new()
	saved.load(auth.session_path)
	check(saved.get_value("auth", "refresh_token") == "rotated-refresh", "rotated refresh token is saved")
	var requests = auth.requests
	check(await auth.restore_session() and auth.requests == requests, "title continue reuses a valid active session")
	auth._expires_at = 0
	fetch_token(auth)
	var token = await auth.get_id_token()
	await get_tree().process_frame
	check(token == "renewed-id" and pending_token == token and auth.requests == requests + 1, "concurrent consumers share one refresh")
	auth._expires_at = 0
	auth.response = result(0, {})
	check((await auth.get_id_token()).is_empty(), "network failure does not expose an expired ID token")
	check(auth.has_saved_session(), "temporary network failure preserves remembered login")
	auth.response = result(400, {"error":{"message":"INVALID_REFRESH_TOKEN"}})
	check(not await auth.restore_session() and not auth.has_saved_session(), "revoked session is forgotten")
	auth.response = result(200, {"user_id":"test-user", "id_token":"renewed-id", "refresh_token":"rotated-refresh", "expires_in":"3600"})
	auth.uid = "test-user"
	auth._refresh_token = "test-refresh"
	auth._expires_at = 0
	fetch_token(auth)
	auth.sign_out()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not auth.is_signed_in() and not auth.has_saved_session() and pending_token.is_empty(), "late refresh cannot undo explicit sign out")
	auth.queue_free()
	Secrets.firebase_api_key = original_key
	print("AUTH SESSION: %d failures" % failures)
	await Audio.shutdown()
	get_tree().quit(failures)
