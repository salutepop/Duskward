extends RefCounted
## Presentation-only Korean catalog. Stable model/save IDs are never renamed.
var strings: Dictionary = {}
var notices: Dictionary = {}
func _init() -> void:
 var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_ko.json"))
 if catalog is Dictionary:
  strings=catalog.get("strings",{})
  notices=catalog.get("legacy_notice_keys",{})
func text(key: String, values: Dictionary = {}) -> String:
 var result: String=str(strings.get(key,key))
 for field in values:
  result=result.replace("{"+str(field)+"}",str(values[field]))
 return result
func notice_key(value: String) -> String:
 return str(notices.get(value,""))
