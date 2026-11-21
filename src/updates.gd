class_name Updates
extends Node
## Notices when a newer build has been published. On the web the build
## writes version.json beside the game; this fetches it, bypassing every
## cache, and compares it with the running version. Elsewhere, and in local
## runs ("dev"), it never reports anything.

signal available(version: String)

const EVERY := 120.0          ## seconds between checks at most

var _request := HTTPRequest.new()
var _last := -EVERY
var _busy := false


func _ready() -> void:
	add_child(_request)
	_request.request_completed.connect(_on_completed)


## Checks, unless one ran in the last EVERY seconds.
func check() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _busy or now - _last < EVERY or not OS.has_feature("web") or Ui.version() == "dev":
		return
	_last = now
	# The page's own address, so the check works wherever the game is hosted;
	# a fresh query defeats every cache between here and the server.
	var base: String = JavaScriptBridge.eval("location.href.split(/[?#]/)[0].replace(/[^/]*$/, '')")
	if _request.request("%sversion.json?t=%d" % [base, Time.get_unix_time_from_system()]) == OK:
		_busy = true


## Loads the page again, which brings the new build.
func reload() -> void:
	JavaScriptBridge.eval("location.reload()")


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and data.get("version", "") is String:
		var latest: String = data.version
		if not latest.is_empty() and latest != Ui.version():
			available.emit(latest)
