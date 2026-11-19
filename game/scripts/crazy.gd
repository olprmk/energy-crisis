class_name Crazy
extends Node
## CrazyGames build (export preset "CrazyGames", custom feature "crazygames"): talks to the CrazyGames SDK v3.
## The page loads the SDK and starts SDK.init() itself (export_presets.cfg, html/head_include of that preset)
## and leaves window.cgDone = true when it is ready (or failed). Everything here does nothing in other builds.
##
## What the game does on CrazyGames:
##   * gameplay_start() when a floor starts, gameplay_stop() on every break (results, menu): SDK.game events;
##   * the language: Ukrainian for players in Ukraine (SDK.user.systemInfo.countryCode "UA"), else English
##     (the page decides it, like the GitHub build, and passes it in window.ecLang);
##   * the player's name: their CrazyGames username (no name screen: the game opens on the character choice);
##   * SDK.game.settings.muteAudio: the site's mute switch silences the game;
##   * "back" is Q instead of Esc (Esc leaves the site's fullscreen).

static var enabled := OS.has_feature("crazygames") or OS.get_cmdline_user_args().has("--crazygames")   # the flag: testing

var username := ""          # CrazyGames username ("" when not signed in or no SDK)
var _sdk = null             # JavaScriptObject window.CrazyGames.SDK
var _playing := false
var _settings_cb            # keep the JS callback alive


## Wait (up to `timeout` s) until the page has initialised the SDK, then read the user and the settings.
func setup(timeout := 6.0) -> void:
	if not enabled or not OS.has_feature("web"):
		return
	var t := 0.0
	while t < timeout and not bool(JavaScriptBridge.eval("window.cgDone === true", true)):
		await get_tree().process_frame
		t += get_process_delta_time()
	var win = JavaScriptBridge.get_interface("window")
	if win == null or win.CrazyGames == null or not bool(JavaScriptBridge.eval("window.cgOk === true", true)):
		print("CrazyGames SDK: not available")
		return
	_sdk = win.CrazyGames.SDK
	var user = JavaScriptBridge.eval("window.cgUser || ''", true)
	username = user if user is String else ""
	_apply_mute()
	_settings_cb = JavaScriptBridge.create_callback(func(_args): _apply_mute())
	_sdk.game.addSettingsChangeListener(_settings_cb)
	print("CrazyGames SDK: ", JavaScriptBridge.eval("window.CrazyGames.SDK.environment", true), " user '", username, "'")


func gameplay_start() -> void:
	if _sdk and not _playing:
		_playing = true
		_sdk.game.gameplayStart()


func gameplay_stop() -> void:
	if _sdk and _playing:
		_playing = false
		_sdk.game.gameplayStop()


## A big moment (the whole building saved): the site celebrates with the player.
func happytime() -> void:
	if _sdk:
		_sdk.game.happytime()


func _apply_mute() -> void:
	var muted := bool(JavaScriptBridge.eval("!!(window.CrazyGames.SDK.game.settings && window.CrazyGames.SDK.game.settings.muteAudio)", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
