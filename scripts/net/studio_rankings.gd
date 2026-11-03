class_name StudioRankings
extends RefCounted
## Public studio scores only: never publish email, tokens or save files.

static func endpoint() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % Secrets.firebase_project_id.uri_encode()

static func decode(rows: Array) -> Array:
	var entries: Array = []
	for row in rows:
		if not row is Dictionary or not row.has("document"): continue
		var doc: Dictionary = row["document"]
		var fields: Dictionary = doc.get("fields", {})
		entries.append({"name": str(fields.get("studio", {}).get("stringValue", "Studio")), "fame": int(fields.get("fame", {}).get("integerValue", 0)), "reputation": int(fields.get("reputation", {}).get("integerValue", 0)), "ours": str(doc.get("name", "")).get_file() == FirebaseAuth.uid})
	return entries

static func fetch(owner_node: Node, metric: String) -> Dictionary:
	if Secrets.firebase_project_id.is_empty(): return {"error": "ranking_setup"}
	if not FirebaseAuth.is_signed_in(): return {"error": "ranking_signin"}
	var token = await FirebaseAuth.get_id_token()
	if token.is_empty(): return {"error": "ranking_signin"}
	metric = "reputation" if metric == "reputation" else "fame"
	var query = {"structuredQuery": {"from": [{"collectionId": "studio_rankings"}], "orderBy": [{"field": {"fieldPath": metric}, "direction": "DESCENDING"}], "limit": 50}}
	var response = await Http.post(owner_node, endpoint() + ":runQuery", PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"]), JSON.stringify(query).to_utf8_buffer(), 20)
	if response.code != 200: return {"error": "ranking_denied" if response.code in [403, 404] else "ranking_error"}
	var data = JSON.parse_string(response.body.get_string_from_utf8())
	if not data is Array: return {"error": "ranking_error"}
	return {"entries": decode(data)}

static func publish(owner_node: Node) -> String:
	if not FirebaseAuth.is_signed_in() or FirebaseAuth.is_anonymous: return "ranking_signin"
	var token = await FirebaseAuth.get_id_token()
	if token.is_empty(): return "ranking_signin"
	var fields = {"studio": {"stringValue": Game.studio_name.left(24)}, "fame": {"integerValue": str(maxi(0, Game.fame))}, "reputation": {"integerValue": str(clampi(Game.reputation, 0, 100))}}
	var result = await Http._send(owner_node, endpoint() + "/studio_rankings/" + FirebaseAuth.uid.uri_encode(), PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"]), HTTPClient.METHOD_PATCH, JSON.stringify({"fields": fields}).to_utf8_buffer(), 20)
	return "ranking_published" if result.code == 200 else ("ranking_denied" if result.code in [403, 404] else "ranking_error")
