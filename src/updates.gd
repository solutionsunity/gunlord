class_name Updates
extends Node
## Notices when a newer build has been published, bypassing every cache, and
## compares it with the running version. On the web the build writes
## version.json beside the game; on Android the source is the latest GitHub
## release, whose APK installs over this one. Elsewhere, and in local runs
## ("dev"), it never reports anything.

signal available(version: String)

const EVERY := 120.0          ## seconds between checks at most
const CACHE_PREFIX := "Gunlord-sw-cache-"   ## the service worker's caches: the project name, then Godot's suffix
const LATEST_RELEASE := "https://api.github.com/repos/solutionsunity/gunlord/releases/latest"

var _request := HTTPRequest.new()
var _last := -EVERY
var _busy := false
var _apk := ""                ## Android: the newer release's APK, once one is found


func _ready() -> void:
	add_child(_request)
	_request.request_completed.connect(_on_completed)


## Checks, unless one ran in the last EVERY seconds.
func check() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _busy or now - _last < EVERY or Ui.version() == "dev":
		return
	var url := ""
	if OS.has_feature("web"):
		# The page's own address, so the check works wherever the game is hosted;
		# a fresh query defeats every cache between here and the server.
		var base: String = JavaScriptBridge.eval("location.href.split(/[?#]/)[0].replace(/[^/]*$/, '')")
		url = "%sversion.json?t=%d" % [base, Time.get_unix_time_from_system()]
	elif OS.has_feature("android"):
		url = LATEST_RELEASE
	else:
		return
	_last = now
	if _request.request(url) == OK:
		_busy = true


## Brings the new build. On the web: drops the service worker and the build it
## keeps for offline play (an installed game would start from them again), then
## loads the page afresh; the next start installs the worker anew, for the new
## build. On Android: opens the release's APK, which the browser downloads to
## install over this one, keeping the player's progress.
func reload() -> void:
	if OS.has_feature("android"):
		OS.shell_open(_apk)
		return
	JavaScriptBridge.eval("""Promise.all([
		'serviceWorker' in navigator ? navigator.serviceWorker.getRegistration().then((r) => r && r.unregister()) : null,
		'caches' in self ? caches.keys().then((keys) => Promise.all(keys.filter((k) => k.startsWith('%s')).map((k) => caches.delete(k)))) : null,
	]).finally(() => location.reload())""" % CACHE_PREFIX)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var latest := ""
	if OS.has_feature("android"):
		# A release is tagged vX.Y.Z and carries the APK the build attached.
		latest = String(data.get("tag_name", "")).trim_prefix("v")
		_apk = ""
		for asset: Variant in data.get("assets", []):
			if asset is Dictionary and String(asset.get("name", "")).ends_with(".apk"):
				_apk = asset.get("browser_download_url", "")
		if _apk.is_empty():
			return
	elif data.get("version", "") is String:
		latest = data.version
	if not latest.is_empty() and latest != Ui.version():
		available.emit(latest)
