class_name Http
extends RefCounted
## One-shot HTTP helpers: create an HTTPRequest under `owner_node`, await it, free it.
## Result: {code: int, body: PackedByteArray, headers: PackedStringArray, error: String}


static func post(owner_node: Node, url: String, headers: PackedStringArray, body: PackedByteArray, timeout := 30.0) -> Dictionary:
	return await _send(owner_node, url, headers, HTTPClient.METHOD_POST, body, timeout)


static func fetch(owner_node: Node, url: String, timeout := 60.0) -> Dictionary:
	return await _send(owner_node, url, PackedStringArray(), HTTPClient.METHOD_GET, PackedByteArray(), timeout)


static func json_of(res: Dictionary) -> Dictionary:
	var body: PackedByteArray = res["body"]
	if body.is_empty():
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


static func _send(owner_node: Node, url: String, headers: PackedStringArray, method: int, body: PackedByteArray, timeout: float) -> Dictionary:
	var http = HTTPRequest.new()
	http.timeout = timeout
	owner_node.add_child(http)
	var err = http.request_raw(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"code": 0, "body": PackedByteArray(), "headers": PackedStringArray(), "error": error_string(err)}
	var result: Array = await http.request_completed
	http.queue_free()
	var ok = int(result[0]) == HTTPRequest.RESULT_SUCCESS
	return {
		"code": int(result[1]),
		"body": result[3],
		"headers": result[2],
		"error": "" if ok else "network error (%d)" % int(result[0]),
	}
