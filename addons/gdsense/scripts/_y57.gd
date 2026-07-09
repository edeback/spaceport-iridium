@tool
class_name _y57
extends Node
signal _m76(_f36: String, _m72: Array, _x6: String, _c87: String)
signal _r52
signal _l24(_g51: int, _m26: String)
signal _o39
signal _j33(_f79: int, _p97: int, _v16: int)
signal _a52(_q5: String, _e88: int)
signal _i1(success: bool)
signal _u38(refactored_code: String, original_hash: String, function_name: String)
signal _l86(_v16: int, breakdown: Array, _o89: int)
signal _a7(_z33: Dictionary)
signal _r2(_w39: String, _y88: String, _r27: float, _p18: String)
signal _j20(message: String)
signal _q20(_a15: String, _z18: String)
var _g99: HTTPRequest
var _u68: HTTPRequest
var _k18: HTTPRequest
var _g36: HTTPRequest
var _e41: HTTPRequest
var _d3: HTTPRequest
var _w1: String = ""
var _d89: bool = false
var _x49: String = "https://api.gdsense.com/api/v1"
var _r34: int = 0
var _q8: String = ""
var _z75: String = ""
var _a88: Dictionary = {}  
var _l96: Dictionary = {}  
var _j25: String = ""  
const _y7 = 86400  
var _g46: String = ""
const _m2 = {
	"GROUP_FREE": [
		"openai/gpt-oss-20b",          
		"gemini-2.5-flash-lite",       
		"gpt-5-nano"                   
	],
	"GROUP_STD": [
		"openai/gpt-oss-120b",         
		"gemini-2.5-flash",            
		"gpt-5.1-codex-mini"           
	],
	"GROUP_PREM": [
		"moonshotai/kimi-k2-instruct-0905",  
		"moonshotai/kimi-k2-thinking-maas",  
		"gemini-3-flash-preview",      
		"gemini-3-pro-preview",        
		"gemini-2.5-pro",              
		"gpt-5.1-codex"                
	]
}
const _w33 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}
const _s76 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
func _enter_tree() -> void:
	_g99 = HTTPRequest.new()
	add_child(_g99)
	_g99.request_completed.connect(_r87)
	_u68 = HTTPRequest.new()
	add_child(_u68)
	_u68.request_completed.connect(_o56)
	_u68.timeout = 0.5  
	_k18 = HTTPRequest.new()
	add_child(_k18)
	_k18.request_completed.connect(_p11)
	_k18.timeout = 30.0  
	_g36 = HTTPRequest.new()
	add_child(_g36)
	_g36.request_completed.connect(_v9)
	_g36.timeout = 5.0  
	_e41 = HTTPRequest.new()
	add_child(_e41)
	_e41.request_completed.connect(_j93)
	_e41.timeout = 10.0  
	_d3 = HTTPRequest.new()
	add_child(_d3)
	_d3.request_completed.connect(_f70)
	_d3.timeout = 10.0  
	_c51()
	_l1()
	_o87()
	_d70()
	_v76()
	_i6.call_deferred()
	_m7.call_deferred()
func _r87(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_l24.emit(0, "Network error")
		return
	if _g51 != 200:
		if _g51 == 401:
			_r52.emit()
		elif _g51 == 403:
			var _q22 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _v55 = json.parse(_h62.get_string_from_utf8())
			if _v55 == OK:
				var _o48 = json.get_data()
				if _o48 is Dictionary and _o48.has("message"):
					_q22 = _o48.get("message", _q22)
			_l24.emit(_g51, _q22)
		elif _g51 == 429:
			var _q22 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _v55 = json.parse(_h62.get_string_from_utf8())
			if _v55 == OK:
				var _o48 = json.get_data()
				if _o48 is Dictionary:
					var _y88 = _o48.get("group", "")
					var _p18 = _o48.get("reset_date", "")
					if not _y88.is_empty():
						if not _p18.is_empty():
							_q22 = "You've exceeded your quota for %s. Resets on %s." % [_y88, _s53(_p18)]
						else:
							_q22 = "You've exceeded your quota for %s." % _y88
					elif _o48.has("message"):
						_q22 = _o48.get("message", _q22)
			_l24.emit(_g51, _q22)
		elif _g51 == 400:
			var _q22 = "Bad request"
			var json = JSON.new()
			var _v55 = json.parse(_h62.get_string_from_utf8())
			if _v55 == OK:
				var _o48 = json.get_data()
				if _o48 is Dictionary and _o48.has("message"):
					_q22 = _o48.get("message", "Bad request")
			_l24.emit(_g51, _q22)
		elif _g51 == 422:
			_l24.emit(_g51, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_l24.emit(_g51, "Server returned an error")
		return
	var json = JSON.new()
	var error = json.parse(_h62.get_string_from_utf8())
	if error != OK:
		_l24.emit(_g51, "Invalid JSON response")
		return
	var _o48 = json.get_data()
	if not _o48 is Dictionary:
		_l24.emit(_g51, "JSON response is not a dictionary.")
		return
	if not _o48.has("content"):
		_l24.emit(_g51, "Response does not contain 'content' field.")
		return
	var content = _o48.get("content", "")
	var _m72 = []
	if _o48.has("documentation_sources"):
		var _r22 = _o48.get("documentation_sources", [])
		if _r22 is Array:
			for source in _r22:
				if source is Dictionary:
					_m72.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})
	if _o48.has("response_id"):
		_q8 = _o48.get("response_id", "")
	else:
		pass
	var _x6 = ""
	if _o48.has("thought_signature"):
		_x6 = _o48.get("thought_signature", "")
		_j25 = _x6
	else:
		_j25 = ""
	var _c87 = ""
	if _o48.has("enhanced_user_message"):
		_c87 = _o48.get("enhanced_user_message", "")
	if _o48.has("quota_warning") and _o48.get("quota_warning") is Dictionary:
		var _e54 = _o48.get("quota_warning")
		var _w39 = _e54.get("severity", "notice").to_lower()
		var _y88 = _e54.get("model_group", "")
		var _r27 = _e54.get("usage_percentage", 0.0)
		var _p18 = _e54.get("reset_date", "")
		match _w39:
			"notice":
				_w39 = "medium"
			"warning":
				_w39 = "high"
			"critical", "limit_reached":
				_w39 = "critical"
			_:
				_w39 = "medium"
		var _z48 = "%s_%s_%d" % [_y88, _w39, int(_r27 / 5) * 5]  
		if not _y88.is_empty() and not _l96.has(_z48):
			_l96[_z48] = Time.get_ticks_msec()
			_r2.emit(_w39, _y88, _r27, _p18)
	if _o48.has("truncation_warning"):
		var _m96 = _o48.get("truncation_warning", "")
		if _m96 is String and not _m96.is_empty():
			_j20.emit(_m96)
	if _o48.has("tier"):
		var _m18 = _o48.get("tier", "")
		if _m18 is String and not _m18.is_empty():
			var _y35 = _a88.get("tier", "")
			if _m18 != _y35:
				_a88["tier"] = _m18
				_a7.emit(_a88)
	for _n79 in _l42:
		if _n79.begins_with("X-Usage-Warning:"):
			var _n76 = _n79.split(": ", true, 1)[1] if _n79.contains(": ") else ""
		elif _n79.begins_with("X-Model-Group:"):
			var _d75 = _n79.split(": ", true, 1)[1] if _n79.contains(": ") else ""
	_m76.emit(content, _m72, _x6, _c87)
	if _o48.has("usage"):
		var _o24 = _o48.get("usage", {})
		var _f79 = _o24.get("prompt_tokens", 0)
		var _p97 = _o24.get("completion_tokens", 0)
		var _v16 = _o24.get("total_tokens", 0)
		_j33.emit(_f79, _p97, _v16)
func _l1() -> void:
	var _j27 := ConfigFile.new()
	var error := _j27.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _d89:
			var env = _j83()
			_w1 = _j27.get_value("api_keys", env, "")
			if _w1.is_empty():
				_w1 = _j27.get_value("plugin", "api_key", "")
				if not _w1.is_empty() and env == "production":
					_j27.set_value("api_keys", "production", _w1)
					_j27.save("user://gdsense_api_key.cfg")
		else:
			_w1 = _j27.get_value("api_keys", "production", "")
			if _w1.is_empty():
				_w1 = _j27.get_value("plugin", "api_key", "")
	else:
		pass
func _s7(_j26: String) -> void:
	var _j27 := ConfigFile.new()
	_j27.load("user://gdsense_api_key.cfg")  
	if _d89:
		var env = _j83()
		_j27.set_value("api_keys", env, _j26)
	else:
		_j27.set_value("api_keys", "production", _j26)
	if not _d89 or _j83() == "production":
		_j27.set_value("plugin", "api_key", _j26)
	_j27.save("user://gdsense_api_key.cfg")
	_w1 = _j26
	_o39.emit()
	_m36.call_deferred()
func _e21() -> String:
	return _w1
func _h10() -> String:
	return _x49
func _d31() -> bool:
	return not _w1.strip_edges().is_empty()
func _y64() -> Dictionary:
	return _a88
func _t11(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""
func _s100(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _w1)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
func _c80() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")
		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_s100(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_s100(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_s100(model)  
		return model
	return "llama-3.1-8b-instant"
func _c51() -> void:
	var _w95 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_d89 = _w95 != null
	if _w95:
		_w95.close()
	if _d89:
		pass
func _c4() -> bool:
	return _d89
func _o87() -> void:
	if not _d89:
		_x49 = "https://api.gdsense.com/api/v1"
		return
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_x49 = "http://localhost:8080/api/v1"
		else:
			_x49 = "https://api.gdsense.com/api/v1"
func _z10(environment: String) -> void:
	if not _d89:
		return
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_o87()
	_l1()
func _j83() -> String:
	if not _d89:
		return "production"
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"
func _i16(messages: Array, _l5: String = "", _r97: String = "", context_metadata: Dictionary = {}) -> void:
	_l1() 
	_y17()
	var _m85 := _w1.strip_edges(true, true)
	if _m85.is_empty():
		_r52.emit()
		return
	if _g99.is_processing():
		return
	var _l42: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _m85
	]
	var _h82 = _c80()
	var _y10 = {
		"messages": messages,
		"model": _h82,
		"godotVersion": _p39(),
		"chat_session_id": _z75
	}
	if not context_metadata.is_empty():
		_y10["context_metadata"] = context_metadata
	if not _l5.is_empty():
		_y10["command"] = _l5
	if not _r97.is_empty():
		_y10["function_context"] = _r97
	var _x99 = _c47()
	if _x99.size() > 0:
		_y10["custom_rules"] = _x99
	var _m90 = _j58()
	if not _m90.is_empty():
		_y10["parametersOverride"] = _m90
	var _h62: String = JSON.stringify(_y10)
	if _y10.has("custom_rules"):
		var _r47 = _y10["custom_rules"]
	else:
		pass
	var _a28 = _x49 + "/completion"
	var error = _g99.request(_a28, _l42, HTTPClient.METHOD_POST, _h62)
	if error != OK:
		_l24.emit(0, "Failed to start request.")
		return 
func _e66(context: Dictionary) -> void:
	_l1() 
	var _m85 := _w1.strip_edges(true, true)
	if _m85.is_empty():
		return
	if is_instance_valid(_u68):
		if _u68.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_u68.cancel_request()
	var _l42: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _m85
	]
	var _h62: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	_r34 = Time.get_ticks_msec()
	var _a28 = _x49 + "/autocomplete"
	var error = _u68.request(_a28, _l42, HTTPClient.METHOD_POST, _h62)
	if error != OK:
		return
func _o56(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	var _e88 = Time.get_ticks_msec() - _r34
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		return
	if _g51 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_h62.get_string_from_utf8())
	if error != OK:
		return
	var _o48 = json.get_data()
	if not _o48 is Dictionary:
		return
	var _q5 = _o48.get("suggestion", "")
	if _q5.is_empty():
		return
	_a52.emit(_q5, _e88)
var _m74: Dictionary = {}  
func _o8(function_name: String, _w13: String, _m39: String, file_path: String = "", model: String = "") -> void:
	_l1() 
	var _m85 := _w1.strip_edges(true, true)
	if _m85.is_empty():
		_r52.emit()
		return
	if is_instance_valid(_k18):
		if _k18.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_k18.cancel_request()
	else:
		pass
	var _l42: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _m85
	]
	var original_hash = _x45(_w13)
	_m74 = {
		"function_name": function_name,
		"original_hash": original_hash
	}
	if _z75.is_empty():
		_v76()
	var _e65 = model if not model.is_empty() else "gemini-2.5-flash"
	var _n86 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _w13,
		"user_prompt": _m39,
		"editor_version": _p39(),
		"chat_session_id": _z75,
		"model": _e65
	}
	var _h62: String = JSON.stringify(_n86)
	var _a28 = _x49 + "/refactor"
	if not is_instance_valid(_k18):
		_k18 = HTTPRequest.new()
		add_child(_k18)
		_k18.request_completed.connect(_p11)
		_k18.timeout = 30.0
	var error = _k18.request(_a28, _l42, HTTPClient.METHOD_POST, _h62)
	if error != OK:
		_l24.emit(0, "Failed to start refactor request.")
		return
func _p11(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_l24.emit(0, "Network error during refactor")
		return
	if _g51 != 200:
		var _q22 = ""
		var json = JSON.new()
		var _v55 = json.parse(_h62.get_string_from_utf8())
		var _o48 = {}
		if _v55 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_o48 = data
		if _g51 == 401:
			_r52.emit()
		elif _g51 == 403:
			_q22 = "Refactor is not available in your tier. Please upgrade."
			if _o48.has("message"):
				_q22 = _o48.get("message", _q22)
			_l24.emit(_g51, _q22)
		elif _g51 == 429:
			_q22 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _o48.has("group") or _o48.has("reset_date"):
				var _y88 = _o48.get("group", "")
				var _p18 = _o48.get("reset_date", "")
				if not _y88.is_empty():
					if not _p18.is_empty():
						_q22 = "You've exceeded your quota for %s. Resets on %s." % [_y88, _s53(_p18)]
					else:
						_q22 = "You've exceeded your quota for %s." % _y88
			elif _o48.has("message"):
				_q22 = _o48.get("message", _q22)
			_l24.emit(_g51, _q22)
		elif _g51 == 400:
			_q22 = "Bad refactor request"
			if _o48.has("message"):
				_q22 = _o48.get("message", _q22)
			_l24.emit(_g51, _q22)
		elif _g51 == 422:
			_q22 = "Refactor request validation failed."
			if _o48.has("message"):
				_q22 = _o48.get("message", _q22)
			_l24.emit(_g51, _q22)
		else:
			_q22 = "Server returned an error during refactor (code: %d)" % _g51
			if _o48.has("message"):
				_q22 = _o48.get("message", _q22)
			elif _o48.has("error"):
				_q22 = _o48.get("error", _q22)
			_l24.emit(_g51, _q22)
		return
	var json = JSON.new()
	var error = json.parse(_h62.get_string_from_utf8())
	if error != OK:
		_l24.emit(_g51, "Invalid JSON response from refactor")
		return
	var _o48 = json.get_data()
	if not _o48 is Dictionary:
		_l24.emit(_g51, "Refactor response is not a dictionary")
		return
	if not _o48.has("rewritten_func"):
		_l24.emit(_g51, "Refactor response missing 'rewritten_func' field")
		return
	var refactored_code = _o48.get("rewritten_func", "")
	if refactored_code.is_empty():
		_l24.emit(_g51, "Refactor response contains empty code")
		return
	var function_name = _m74.get("function_name", "")
	var original_hash = _m74.get("original_hash", "")
	_m74.clear()
	_u38.emit(refactored_code, original_hash, function_name)
func _x45(text: String) -> String:
	var _j59 = HashingContext.new()
	_j59.start(HashingContext.HASH_SHA256)
	_j59.update(text.to_utf8_buffer())
	var _n11 = _j59.finish()
	return _n11.hex_encode()
func _p39() -> String:
	var _g90 = Engine.get_version_info()
	return "%d.%d.%d" % [_g90.major, _g90.minor, _g90.patch]
func _c47() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _l37 = config.get_value("custom_rules", "rules_text", "")
		if not _l37.is_empty():
			var _g15 = _l37.split("\n")
			var _r15 = PackedStringArray()
			for _x54 in _g15:
				var _n85 = _x54.strip_edges()
				if not _n85.is_empty():
					_r15.append(_n85)
			return _r15
	return PackedStringArray()
func _j58() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _o4 = {}
		var _k6 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		if _k6 > 0.0:
			_o4["temperature"] = _k6
		if max_tokens > 0:
			_o4["max_tokens"] = max_tokens
		return _o4
	return {}
func _p75(_l37: String) -> Dictionary:
	var _x97 = {"valid": true, "errors": []}
	if _l37.length() > 500:
		_x97["valid"] = false
		_x97["errors"].append("Custom rules must be under 500 characters")
	var _t70 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]
	var _g75 = _l37.to_lower()
	for _y99 in _t70:
		if _g75.find(_y99) != -1:
			_x97["valid"] = false
			_x97["errors"].append("System instruction overrides are not allowed")
			break
	return _x97
func _n34(_l37: String) -> bool:
	var _p32 = _p75(_l37)
	if not _p32.get("valid", false):
		return false
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _l37)
	config.save("user://gdsense_settings.cfg")
	return true
func _y83(_k6: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _k6)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")
func _x32() -> String:
	return _q8
func _j41() -> String:
	var _e100 = []
	for i in range(32):
		_e100.append(randi() % 16)
	_e100[12] = 4  
	_e100[16] = (_e100[16] & 0x3) | 0x8  
	var _m92 = "0123456789abcdef"
	var _x97 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_x97 += "-"
		_x97 += _m92[_e100[i]]
	return _x97
func _v76() -> void:
	_z75 = _j41()
func _q65() -> String:
	return _z75
func _v74(rating: String, category: String = "", details: String = "") -> void:
	if _q8.is_empty():
		return
	var _m85 := _w1.strip_edges(true, true)
	if _m85.is_empty():
		return
	var _l42: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _m85
	]
	var _q70 = {
		"responseId": _q8,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _z75,
		"context": {
			"model": _c80(),
			"godotVersion": _p39()
		}
	}
	var _h62: String = JSON.stringify(_q70)
	var _k47 = HTTPRequest.new()
	add_child(_k47)
	_k47.request_completed.connect(_i89)
	var _a28 = _x49 + "/feedback"
	var error = _k47.request(_a28, _l42, HTTPClient.METHOD_POST, _h62)
	if error != OK:
		_k47.queue_free()
func _i89(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	var _q33 = null
	for _h61 in get_children():
		if _h61 is HTTPRequest and _h61 != _g99 and _h61 != _u68:
			_q33 = _h61
			break
	if _q33:
		_q33.queue_free()
	var success = _x97 == HTTPRequest.RESULT_SUCCESS and _g51 == 200
	if success:
		pass
	else:
		pass
	_i1.emit(success)
func _d70() -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		if not config.has_section_key("custom_rules", "rules_text"):
			config.set_value("custom_rules", "rules_text", "")
		if not config.has_section_key("parameters", "temperature_override"):
			config.set_value("parameters", "temperature_override", 0.0)
		if not config.has_section_key("parameters", "max_tokens_override"):
			config.set_value("parameters", "max_tokens_override", 0)
		config.save("user://gdsense_settings.cfg")
	else:
		config.set_value("custom_rules", "rules_text", "")
		config.set_value("parameters", "temperature_override", 0.0)
		config.set_value("parameters", "max_tokens_override", 0)
		config.save("user://gdsense_settings.cfg")
func _w87(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _w1.is_empty():
		return
	if _g36 and _g36.is_processing():
		return
	var _l42: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _w1
	]
	var _y10 = {
		"messages": messages,
		"model": _c80(),
		"context_metadata": context_metadata
	}
	var _t31 = JSON.stringify(_y10)
	var _a28 = _x49 + "/context/estimate"
	var error = _g36.request(_a28, _l42, HTTPClient.METHOD_POST, _t31)
	if error != OK:
		pass
func _v9(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		return
	if _g51 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_h62.get_string_from_utf8())
	if error != OK:
		return
	var _o48 = json.get_data()
	if not _o48 is Dictionary:
		return
	var _v16 = _o48.get("tokens", 0)
	var breakdown = _o48.get("breakdown", [])
	var _o89 = _o48.get("context_limit", 128000)
	_l86.emit(_v16, breakdown, _o89)
func _v82() -> void:
	if _d89:
		pass
	var _x99 = _c47()
	var _m90 = _j58()
func _i6() -> void:
	if not _w1.is_empty():
		_v71()
func _v71() -> void:
	var _m85 := _w1.strip_edges(true, true)
	if _m85.is_empty():
		return
	if _e41.is_processing():
		return
	var _l42: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _m85
	]
	var _a28 = _x49 + "/plugin/whoami"
	var error = _e41.request(_a28, _l42, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _j93(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_h78()
		return
	if _g51 != 200:
		_h78()
		return
	var json = JSON.new()
	var error = json.parse(_h62.get_string_from_utf8())
	if error != OK:
		_h78()
		return
	var _o48 = json.get_data()
	if not _o48 is Dictionary:
		_h78()
		return
	_a88 = _o48
	_a7.emit(_a88)
	_q61()
func _h78() -> void:
	_a88 = {
		"tier": "FREE",
		"features": {
			"explain": true,
			"refactor": false
		},
		"credits": {
			"used": 0.0,
			"limit": 50,
			"pct": 0,
			"remaining": 50.0
		}
	}
	_a7.emit(_a88)
func _q88() -> String:
	return _f89(_a88.get("tier", "FREE"))
func _f89(_c45: String) -> String:
	if _c45 == null:
		return "FREE"
	var _o31 = _c45.strip_edges()
	if _o31.is_empty():
		return "FREE"
	_o31 = _o31.replace("-", "_").replace(" ", "_").to_upper()
	return _o31
func _s53(_s25: String) -> String:
	if _s25.is_empty():
		return ""
	var _t35 = _s25.split("T")[0] if "T" in _s25 else _s25
	var _n66 = _t35.split("-")
	if _n66.size() < 3:
		return _s25  
	var year = _n66[0]
	var month = int(_n66[1]) if _n66[1].is_valid_int() else 0
	var day = int(_n66[2]) if _n66[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _s25  
	var _v36 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_v36[month - 1], day, year]
func _w90() -> Dictionary:
	return _a88.get("features", {"explain": true, "refactor": true})
func _e84() -> Dictionary:
	var _q59 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _a88.get("credits", _q59)
func _z36() -> bool:
	var features = _w90()
	return features.get("refactor", true)
func _h58() -> Array:
	if _a88.has("allowed_models"):
		var _w51 = _a88["allowed_models"]
		if _w51 is Array and _w51.size() > 0:
			var _q50: Array = []
			for model in _w51:
				if model is Dictionary and model.has("id"):
					_q50.append(model["id"])
			if _q50.size() > 0:
				return _q50
	var _p53 = _q88()
	var _s80 = _w33.get(_p53, ["GROUP_FREE"])
	var _n35: Array = []
	for _y88 in _s76:
		if _y88 in _s80 and _m2.has(_y88):
			_n35.append_array(_m2[_y88])
	return _n35
func _q95() -> Array:
	if _a88.has("allowed_models"):
		var _w51 = _a88["allowed_models"]
		if _w51 is Array and _w51.size() > 0:
			return _w51
	return []
func _q61() -> void:
	var _f55 = _e84()
	var used = _f55.get("used", 0.0)
	var limit = _f55.get("limit", 0)
	var _r27 = _f55.get("pct", 0)
	if limit <= 0:
		return  
	var _z48 = ""
	var _w39 = ""
	if _r27 >= 95:
		_z48 = "credits_95"
		_w39 = "critical"
	elif _r27 >= 90:
		_z48 = "credits_90"
		_w39 = "high"
	elif _r27 >= 85:
		_z48 = "credits_85"
		_w39 = "medium"
	elif _r27 >= 80:
		_z48 = "credits_80"
		_w39 = "low"
	if not _z48.is_empty() and not _l96.has(_z48):
		_l96[_z48] = Time.get_ticks_msec()
		var _h39 = _a88.get("renewal_date", "")
		_r2.emit(_w39, "credits", float(_r27), _h39)
func _m36() -> void:
	_a88.clear()
	_v71()
func _e3(_m18: String) -> void:
	if _m18.is_empty():
		return
	var _y35 = _a88.get("tier", "")
	if _m18 != _y35:
		_a88["tier"] = _m18
		_a7.emit(_a88)
func _y17() -> void:
	var _v50 = Time.get_ticks_msec()
	var _s72 = []
	for _z48 in _l96:
		var _q16 = _l96[_z48]
		if (_v50 - _q16) > 3600000:  
			_s72.append(_z48)
	for _j26 in _s72:
		_l96.erase(_j26)
func _m7() -> void:
	if not _z55():
		return
	var _a28 = "https://api.gdsense.com/api/v1/plugin/latest-version"
	var _l42: PackedStringArray = [
		"Content-Type: application/json"
	]
	var error = _d3.request(_a28, _l42, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _z55() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  
	var _k57 = config.get_value("updates", "last_check_timestamp", 0)
	var _v50 = int(Time.get_unix_time_from_system())
	return (_v50 - _k57) >= _y7
func _f70(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		return
	if _g51 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_h62.get_string_from_utf8())
	if error != OK:
		return
	var _o48 = json.get_data()
	if not _o48 is Dictionary:
		return
	var _a15 = _o48.get("version", "")
	var is_active = _o48.get("isActive", true)
	if _a15.is_empty():
		return
	_o59()
	var _z18 = _t48()
	if is_active and _w42(_z18, _a15) < 0:
		_q20.emit(_a15, _z18)
	else:
		pass
func _o59() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")
func _w42(current: String, _t82: String) -> int:
	var _n96 = current.split(".")
	var _b9 = _t82.split(".")
	var _o80 = max(_n96.size(), _b9.size())
	while _n96.size() < _o80:
		_n96.append("0")
	while _b9.size() < _o80:
		_b9.append("0")
	for i in range(_o80):
		var _c55 = int(_n96[i])
		var _k55 = int(_b9[i])
		if _c55 < _k55:
			return -1
		elif _c55 > _k55:
			return 1
	return 0
func _g68() -> String:
	return _t48()
func _t48() -> String:
	if _g46.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_g46 = config.get_value("plugin", "version", "0.0.0")
		else:
			_g46 = "0.0.0"
	return _g46
