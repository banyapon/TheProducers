extends Node
## Loads API keys from user://secrets.cfg or res://config/secrets.cfg (gitignored).
## Nothing secret is hard-coded in scripts.

const PATHS := ["user://secrets.cfg", "res://config/secrets.cfg"]

var firebase_api_key := ""
var firebase_project_id := ""
var cloudinary_cloud := ""
var cloudinary_key := ""
var cloudinary_secret := ""
var cloudinary_root := "the_producers"
var signing_mode := "local"
var signing_url := ""
var music_provider := "local"
var hf_token := ""
var hf_model_url := ""


func _ready() -> void:
	var cfg := ConfigFile.new()
	var loaded := false
	for path in (["res://config/public.cfg"] if OS.has_feature("web") else PATHS):
		if cfg.load(path) == OK:
			loaded = true
			break
	if not loaded:
		push_warning("No secrets.cfg found — Firebase/Cloudinary disabled (offline play only).")
		return
	firebase_api_key = cfg.get_value("firebase", "api_key", "")
	firebase_project_id = cfg.get_value("firebase", "project_id", "")
	_parse_cloudinary_url(cfg.get_value("cloudinary", "url", ""))
	signing_mode = cfg.get_value("cloudinary", "signing_mode", "local")
	signing_url = cfg.get_value("cloudinary", "signing_url", "")
	cloudinary_root = cfg.get_value("cloudinary", "root_folder", "the_producers")
	music_provider = cfg.get_value("music", "provider", "local")
	hf_token = cfg.get_value("music", "hf_token", "")
	hf_model_url = cfg.get_value("music", "hf_model_url", "")


func has_firebase() -> bool:
	return firebase_api_key != ""


## cloudinary://<api_key>:<api_secret>@<cloud_name>
func _parse_cloudinary_url(url: String) -> void:
	url = url.strip_edges().trim_prefix("CLOUDINARY_URL=").trim_prefix("cloudinary://")
	var at := url.rfind("@")
	if at < 0:
		return
	var credentials := url.left(at)
	cloudinary_cloud = url.substr(at + 1)
	var colon := credentials.find(":")
	if colon < 0:
		return
	cloudinary_key = credentials.left(colon)
	cloudinary_secret = credentials.substr(colon + 1)


## Safe-to-display form of a key: a short prefix, the rest hidden.
static func mask(value: String) -> String:
	if value.is_empty(): return "-"
	return value.left(mini(4, value.length() / 3)) + "****"
