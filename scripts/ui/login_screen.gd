class_name LoginScreen
extends Control
signal login_completed(uid: String)
const TITLE_WALLPAPERS := [
	preload("res://assets/title/producer-alice-wallpaper.png"),
	preload("res://assets/title/producer-alice-wallpaper-2.png"),
]
var email_edit: LineEdit
var password_edit: LineEdit
var status_label: Label
var _busy = false
var _page = "home"
var _home_tab := 0
var _tab = 0
var _pending: Callable
var _identity = ""
var _accepted = [false, false]
var _read = [false, false]
var _mail = ""
var _password = ""
var _legal_only = false
var _layout: TitleLayout
var _services: VBoxContainer
var _quest_catalogue: QuestPanel

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	FirebaseAuth.auth_error.connect(_set_status)
	Locale.language_changed.connect(func(_lang: String):
		if not is_instance_valid(_quest_catalogue) or not _quest_catalogue.visible: _render())
	resized.connect(_layout_title)
	open()

func _set_status(message: String) -> void:
	if not is_instance_valid(status_label): return
	status_label.text = message
	status_label.visible = not message.is_empty()
	_layout_title.call_deferred()

func open() -> void:
	_page = "home"
	_busy = false
	_password = ""
	show()
	_render()

func escape() -> void:
	if is_instance_valid(_quest_catalogue) and _quest_catalogue.visible:
		_quest_catalogue.close()
		return
	if _busy:
		FirebaseAuth.cancel_google()
		return
	if _page == "credits":
		_page = "options"
		_render()
		return
	if _page != "home":
		_page = "home"
		_pending = Callable()
		_render()
	elif _home_tab != 0:
		_password = ""
		_select_home_tab(0)
	else: Audio.quit_game()

func _render() -> void:
	UIKit.clear(self)
	email_edit = null
	password_edit = null
	_services = null
	if _page == "home":
		_render_title()
		return
	var body = UIKit.centered_window(self, 1180, 850)
	var head = HBoxContainer.new()
	body.add_child(head)
	var title = UIKit.label("THE PRODUCERS", 44)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var language_button = UIKit.button("EN / TH", func(): Locale.set_language("en" if Locale.language == "th" else "th"))
	language_button.disabled = _busy
	head.add_child(language_button)
	var options_button = UIKit.button(Locale.text("options"), func(): _page = "options"; _render())
	options_button.disabled = _busy
	head.add_child(options_button)
	if _page == "credits":
		body.add_child(UIKit.label(Locale.text("credits_title"), 38))
		CreditsPage.populate(body, func(): _page = "options"; _render())
		return
	if _page == "legal":
		_legal(body)
		return
	if _page == "options":
		body.add_child(UIKit.label(Locale.text("options"), 36))
		body.add_child(UIKit.button("English", func(): Locale.set_language("en")))
		body.add_child(UIKit.button(Locale.text("language_th"), func(): Locale.set_language("th")))
		var full = CheckBox.new()
		full.text = Locale.text("fullscreen")
		full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		full.toggled.connect(func(on: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		body.add_child(full)
		AudioOptions.add_controls(body)
		RelationshipOptions.add_controls(body)
		body.add_child(UIKit.button(Locale.text("pt_title"), _open_playtest))
		var credits = UIKit.button(Locale.text("credits_title"), func(): _page = "credits"; _render())
		credits.name = "OpenCredits"
		body.add_child(credits)
		_services = VBoxContainer.new()
		body.add_child(_services)
		_refresh_services()
		ServiceStatus.check_all(Secrets)
		var service_timer = Timer.new()
		service_timer.wait_time = 1.0
		service_timer.autostart = true
		service_timer.timeout.connect(_refresh_services)
		body.add_child(service_timer)
		body.add_child(UIKit.button(Locale.text("back"), func(): _page = "home"; _render()))
		return

func _authenticate(signup: bool) -> void:
	if _busy: return
	_mail = _mail.strip_edges().to_lower()
	if not _mail.contains("@") or not _mail.get_slice("@", 1).contains(".") or _password.length() < 6:
		_set_status(Locale.text("auth_invalid"))
		return
	_identity = _mail
	_pending = FirebaseAuth.sign_up.bind(_mail, _password) if signup else FirebaseAuth.sign_in.bind(_mail, _password)
	if signup or not Locale.has_consent(_identity): _request_consent()
	else: _run(_pending, false)

func _restore() -> void:
	var cfg = ConfigFile.new()
	cfg.load(FirebaseAuth.SESSION_PATH)
	_identity = str(cfg.get_value("auth", "email", "")).to_lower()
	_pending = FirebaseAuth.restore_session
	if not _identity.is_empty() and not Locale.has_consent(_identity): _request_consent()
	else: _run(_pending, false)

func _request_consent() -> void:
	_legal_only = false
	_accepted = [false, false]
	_read = [true, false]
	_tab = 0
	_page = "legal"
	_render()

func _legal(body: VBoxContainer) -> void:
	var tabs = HBoxContainer.new()
	body.add_child(tabs)
	for index in 2:
		tabs.add_child(UIKit.button(Locale.text("terms_title" if index == 0 else "privacy_title"), func():
			_tab = index
			_read[index] = true
			_render(), 400))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var copy = UIKit.label(Locale.text("terms_body" if _tab == 0 else "privacy_body"), 26)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(copy)
	if not _legal_only:
		var accept = UIKit.button(Locale.text("accept_continue"), func(): _run(_pending, true))
		for i in 2:
			var check = CheckBox.new()
			check.text = Locale.text("accept_terms" if i == 0 else "accept_privacy")
			check.button_pressed = _accepted[i]
			check.disabled = not _read[i]
			check.toggled.connect(func(on: bool): _accepted[i] = on; accept.disabled = not (_accepted[0] and _accepted[1]))
			body.add_child(check)
		accept.disabled = not (_accepted[0] and _accepted[1])
		body.add_child(UIKit.label(Locale.text("consent_hint"), 22))
		body.add_child(accept)
	body.add_child(UIKit.button(Locale.text("back"), func(): _page = "home"; _render()))
	status_label = UIKit.label("", 22)
	body.add_child(status_label)

func _run(action: Callable, consent: bool) -> void:
	if _busy or not action.is_valid(): return
	if consent and not (_accepted[0] and _accepted[1] and _read[0] and _read[1]): return
	_busy = true
	_page = "home"
	_render()
	if action.get_method() == "sign_in_google": _set_status(Locale.text("google_wait"))
	var ok: bool = await action.call()
	_busy = false
	if ok:
		if consent: Locale.record_consent(FirebaseAuth.email.to_lower() if _identity.is_empty() else _identity)
		_password = ""
		_pending = Callable()
		_identity = ""
		if is_instance_valid(password_edit): password_edit.text = ""
		hide()
		login_completed.emit(FirebaseAuth.uid)
	else:
		var error = status_label.text
		_render()
		_set_status(error)

func _render_title() -> void:
	_layout = TitleLayout.new()
	var art = TextureRect.new()
	art.name = "TitleWallpaper"
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	art.texture = TITLE_WALLPAPERS[0]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(art)
	var blink = Timer.new()
	blink.name = "TitleBlink"
	blink.wait_time = 0.7
	blink.autostart = true
	blink.timeout.connect(func():
		if art.is_visible_in_tree():
			art.texture = TITLE_WALLPAPERS[1] if art.texture == TITLE_WALLPAPERS[0] else TITLE_WALLPAPERS[0])
	art.add_child(blink)
	var logo = TextureRect.new()
	logo.name = "LogoLayer"
	logo.texture = load("res://assets/title/the-producer-logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(logo)
	var toolbar = HBoxContainer.new()
	toolbar.name = "TitleToolbar"
	toolbar.alignment = BoxContainer.ALIGNMENT_END
	toolbar.custom_minimum_size.y = _layout.px("sizes", "toolbar_height")
	toolbar.add_theme_constant_override("separation", _layout.px("gaps", "toolbar_gap"))
	add_child(toolbar)
	var language_button = UIKit.button("EN / TH", func(): Locale.set_language("en" if Locale.language == "th" else "th"), 140)
	language_button.add_theme_font_size_override("font_size", 48)
	language_button.disabled = _busy
	toolbar.add_child(language_button)
	var settings = UIKit.button(Locale.text("options"), func(): _page = "options"; _render(), 160)
	settings.add_theme_font_size_override("font_size", 48)
	settings.disabled = _busy
	toolbar.add_child(settings)
	var panel = PanelContainer.new()
	panel.name = "TitleMenu"
	if _home_tab == 0: panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(panel)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", _layout.px("gaps", "menu_padding") if _home_tab == 0 else 6)
	panel.add_child(body)
	var tabs = HBoxContainer.new()
	tabs.name = "EntryTabs"
	tabs.add_theme_constant_override("separation", _layout.px("gaps", "menu_padding"))
	if _home_tab != 0: body.add_child(tabs)
	else: tabs.hide(); body.add_child(tabs)
	var group = ButtonGroup.new()
	var tab_names = ["play_tab", "signin", "signup"]
	for index in (range(3) if _home_tab != 0 else []):
		var tab = UIKit.button(Locale.text(tab_names[index]), _select_home_tab.bind(index))
		tab.name = ["PlayTab", "SignInTab", "SignUpTab"][index]
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = _home_tab == index
		tab.disabled = _busy
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 42)
		tabs.add_child(tab)
	var content = VBoxContainer.new()
	content.name = "TabContent"
	content.size_flags_vertical = SIZE_FILL
	content.add_theme_constant_override("separation", _layout.px("gaps", "menu_item_gap"))
	body.add_child(content)
	if _home_tab == 0:
		_play_tab(content)
	else:
		_account_tab(content, _home_tab == 2)
	for item in content.get_children():
		if item is Button or item is LineEdit:
			item.add_theme_font_size_override("font_size", 46)
			item.custom_minimum_size.y = 66 if _home_tab == 0 else 54
	if _home_tab == 0:
		var accounts = HBoxContainer.new()
		accounts.name = "AccountLinks"
		accounts.add_theme_constant_override("separation", 16)
		body.add_child(accounts)
		for index in [1, 2]:
			var account_button = UIKit.button(Locale.text("signin" if index == 1 else "signup"), _select_home_tab.bind(index))
			account_button.size_flags_horizontal = SIZE_EXPAND_FILL
			account_button.disabled = _busy
			_style_title_link(account_button)
			accounts.add_child(account_button)
	var foot = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 14)
	body.add_child(foot)
	for spec in [["privacy_link", func(): _legal_only = true; _page = "legal"; _render()], ["home_quit", Audio.quit_game]]:
		var link = UIKit.button(Locale.text(spec[0]), spec[1])
		link.flat = true
		link.disabled = _busy
		link.size_flags_horizontal = SIZE_EXPAND_FILL
		link.add_theme_font_size_override("font_size", 38)
		if _home_tab == 0: _style_title_link(link)
		foot.add_child(link)
	status_label = UIKit.label(Locale.text("auth_busy") if _busy else "", 38)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status_label)
	status_label.visible = not status_label.text.is_empty()
	if _home_tab == 0: status_label.add_theme_color_override("font_color", Color("963c24"))
	var tagline_panel = _title_panel("TitleTaglinePanel")
	tagline_panel.visible = _home_tab == 0
	tagline_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var tagline = VBoxContainer.new()
	tagline.name = "TitleTagline"
	tagline.add_theme_constant_override("separation", 6)
	tagline.mouse_filter = MOUSE_FILTER_IGNORE
	tagline_panel.add_child(tagline)
	tagline.add_child(_title_text("SHIFT the sound. Shape the star.", _layout.px("sizes", "tagline_title"), Color("963c24")))
	tagline.add_child(_title_text(Locale.text("shift_tagline"), _layout.px("sizes", "tagline_body"), Color("536071")))
	var credit_bar = ColorRect.new()
	credit_bar.name = "TitleCreditBar"
	credit_bar.color = Color("121d30")
	credit_bar.anchor_top = 1.0
	credit_bar.anchor_bottom = 1.0
	credit_bar.anchor_right = 1.0
	credit_bar.offset_top = -_layout.px("sizes", "footer_height")
	credit_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(credit_bar)
	var credit = UIKit.label("@2026 Daydev Co., Ltd. & College of Creative Design and Entertainment Technology, Dhurakij Pundit University", 34)
	credit.name = "TitleCredit"
	credit.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit.add_theme_color_override("font_color", Color("fff8eb"))
	credit.mouse_filter = MOUSE_FILTER_IGNORE
	credit_bar.add_child(credit)
	# Spacing is re-applied whenever content, window size or title_layout.cfg changes.
	var watch = Timer.new()
	watch.name = "TitleLayoutWatch"
	watch.wait_time = 0.25
	watch.autostart = true
	watch.timeout.connect(_tick_title)
	add_child(watch)
	_refresh_services()
	_layout_title.call_deferred()

func _layout_title() -> void:
	if _page != "home" or _layout == null or not has_node("TitleMenu"): return
	var blocks = [
		[get_node("TitleToolbar"), _layout.px("gaps", "logo_to_toolbar")],
		[get_node("TitleMenu"), _layout.px("gaps", "toolbar_to_menu")],
	]
	if _home_tab == 0: blocks.append([get_node("TitleTaglinePanel"), _layout.px("gaps", "menu_to_tagline")])
	_layout.stack(size, get_node("LogoLayer"), blocks)

func _tick_title() -> void:
	if OS.is_debug_build() and _layout.changed_on_disk():
		print("[title] title_layout.cfg changed - spacing re-applied")
		_render()
		return
	_refresh_services()
	_layout_title()

func _refresh_services() -> void:
	if not is_instance_valid(_services): return
	var rows = [
		["Google Firebase", ServiceStatus.results.get("firebase", "checking")],
		["Cloudinary", ServiceStatus.results.get("cloudinary", "checking")],
	]
	if _services.get_child_count() != rows.size():
		for row in rows: _services.add_child(_title_text("", _layout.px("sizes", "services_text"), Color.WHITE))
	for i in rows.size():
		var state: String = rows[i][1]
		var line: Label = _services.get_child(i)
		var status = "Connect!" if state == "ok" else ("Checking..." if state == "checking" else "Failed!")
		line.text = "%s %s" % [rows[i][0], status]
		line.add_theme_color_override("font_color", Color("8fe39a") if state == "ok" else (Color("ffd27b") if state == "checking" else Color("ff8a7a")))

func _title_panel(node_name: String) -> PanelContainer:
	var holder = PanelContainer.new()
	holder.name = node_name
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color("201529")
	style.border_color = Color("ffd27b")
	style.border_width_top = 2
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	holder.add_theme_stylebox_override("panel", style)
	add_child(holder)
	return holder

func _title_text(value: String, font_size: int, color: Color) -> Label:
	var copy = Label.new()
	copy.text = Locale.display_game_text(value)
	copy.add_theme_font_size_override("font_size", font_size)
	copy.add_theme_color_override("font_color", color)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	copy.mouse_filter = MOUSE_FILTER_IGNORE
	return copy

func _select_home_tab(index: int) -> void:
	if _busy: return
	_home_tab = clampi(index, 0, 2)
	_render()

func _hint(body: VBoxContainer, key: String) -> void:
	var copy = UIKit.label(Locale.text(key), 40)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.modulate = Color("a1b8a8")
	body.add_child(copy)

func _play_tab(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation", 14)
	var welcome = UIKit.label(Locale.text("welcome"), 44)
	welcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	welcome.add_theme_color_override("font_color", Color("172235"))
	body.add_child(welcome)
	if FirebaseAuth.has_saved_session():
		var saved = UIKit.button(Locale.text("continue"), _restore, 0, "ConfirmButton")
		saved.disabled = _busy or not Secrets.has_firebase()
		saved.name = "ContinueGame"
		_style_title_primary(saved)
		body.add_child(saved)
		var account = UIKit.label(FirebaseAuth.mask_email(FirebaseAuth.saved_session_label()), 36)
		account.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		account.add_theme_color_override("font_color", Color("536071"))
		body.add_child(account)
	var offline = UIKit.button(Locale.text("offline"), _offline_pressed, 0, "" if FirebaseAuth.has_saved_session() else "ConfirmButton")
	offline.disabled = _busy
	offline.name = "OfflineGame"
	if not FirebaseAuth.has_saved_session(): _style_title_primary(offline)
	body.add_child(offline)
	var tutorial = UIKit.button(Locale.text("demo_entry"), func():
		FirebaseAuth.sign_out()
		hide()
		login_completed.emit("demo_career"))
	tutorial.tooltip_text = Locale.text("tutorial_intro")
	tutorial.name = "TutorialGame"
	tutorial.disabled = _busy
	body.add_child(tutorial)
	var quests = UIKit.button("Quest • " + ("เรื่องราวตัวละคร" if Locale.language == "th" else "Story encounters"), _open_quests)
	quests.name = "TitleQuests"
	quests.disabled = _busy
	body.add_child(quests)

func _open_quests() -> void:
	if _busy: return
	_quest_catalogue = QuestPanel.new()
	add_child(_quest_catalogue)
	_quest_catalogue.closed.connect(func():
		_quest_catalogue.queue_free()
		_render.call_deferred())
	_quest_catalogue.open_catalogue(true)

func _style_title_primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var skin = StyleBoxFlat.new()
		skin.bg_color = Color("f48a32") if state == "normal" else (Color("ffc16a") if state == "hover" else (Color("cb6225") if state == "pressed" else Color("c5b9a5")))
		skin.border_color = Color("172235")
		skin.set_border_width_all(3)
		skin.shadow_color = Color("172235")
		skin.shadow_offset = Vector2(0, 4)
		skin.shadow_size = 1
		button.add_theme_stylebox_override(state, skin)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("172235"))

func _style_title_link(button: Button) -> void:
	button.flat = true
	button.add_theme_font_size_override("font_size", 36)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var skin = StyleBoxFlat.new()
		skin.bg_color = Color("f7e7cc") if state in ["hover", "pressed"] else Color(0, 0, 0, 0)
		button.add_theme_stylebox_override(state, skin)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("536071") if state == "disabled" else Color("172235"))

func _offline_pressed() -> void:
	if _busy: return
	FirebaseAuth.sign_out()
	hide()
	_password = ""
	login_completed.emit("")

func _open_playtest() -> void:
	var panel = PlaytestPanel.new()
	panel.can_launch = true
	add_child(panel)
	panel.launch.connect(func(slot: String):
		FirebaseAuth.sign_out()
		hide()
		login_completed.emit(slot))
	panel.closed.connect(panel.queue_free)
	panel.open()

func _account_tab(body: VBoxContainer, signup: bool) -> void:
	if not signup:
		_add_google_button(body)
		var divider = UIKit.label(Locale.text("email_divider"), 38)
		divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		divider.modulate = Color("a1b8a8")
		body.add_child(divider)
	else:
		_hint(body, "signup_hint")
	email_edit = LineEdit.new()
	email_edit.placeholder_text = Locale.text("email")
	email_edit.text = _mail
	email_edit.editable = not _busy
	email_edit.text_changed.connect(func(value: String): _mail = value)
	email_edit.text_submitted.connect(func(_value: String): password_edit.grab_focus())
	body.add_child(email_edit)
	password_edit = LineEdit.new()
	password_edit.secret = true
	password_edit.placeholder_text = Locale.text("password")
	password_edit.text = _password
	password_edit.editable = not _busy
	password_edit.text_changed.connect(func(value: String): _password = value)
	password_edit.text_submitted.connect(func(_value: String): _authenticate(signup))
	body.add_child(password_edit)
	var submit = UIKit.button(Locale.text("signup" if signup else "signin"), _authenticate.bind(signup), 0, "ConfirmButton")
	submit.name = "SubmitAccount"
	submit.disabled = _busy or not Secrets.has_firebase()
	body.add_child(submit)
	if signup: _hint(body, "signup_legal_hint")
	else:
		var guest = UIKit.button(Locale.text("guest"), func(): _run(FirebaseAuth.sign_in_anonymous, false))
		guest.name = "GuestSignIn"
		guest.disabled = _busy or not Secrets.has_firebase()
		body.add_child(guest)

func _add_google_button(body: VBoxContainer) -> void:
	var google = UIKit.button(Locale.text("google_connect"), _on_google_pressed)
	google.name = "GoogleSignIn"
	google.custom_minimum_size.y = 58
	google.disabled = _busy
	google.tooltip_text = "" if FirebaseAuth.has_google() else Locale.text("google_setup")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var skin = StyleBoxFlat.new()
		skin.bg_color = Color("ffffff" if state == "normal" else ("e8eaed" if state == "pressed" else "f2f2f2"))
		skin.border_color = Color("747775")
		skin.set_border_width_all(1)
		skin.set_corner_radius_all(4)
		skin.content_margin_left = 56
		skin.content_margin_right = 18
		skin.content_margin_top = 12
		skin.content_margin_bottom = 12
		google.add_theme_stylebox_override(state, skin)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		google.add_theme_color_override(state, Color("1f1f1f"))
	body.add_child(google)
	var icon = TextureRect.new()
	icon.name = "OfficialGoogleLogo"
	icon.texture = load("res://assets/ui/brand/google-g.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = 18
	icon.offset_right = 50
	icon.offset_top = -16
	icon.offset_bottom = 16
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	google.add_child(icon)
	# Override the game's nearest filter only for the original Google brand asset.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _on_google_pressed() -> void:
	if _busy: return
	if not FirebaseAuth.has_google():
		_set_status(Locale.text("google_setup"))
		return
	_identity = ""
	_pending = FirebaseAuth.sign_in_google
	_request_consent()
