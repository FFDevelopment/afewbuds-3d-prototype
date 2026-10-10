extends "res://account/cloud.gd"
# Local preview adapter. Every account request stops here before HTTP creation.
func request_json(_path: String, _payload: Dictionary) -> Dictionary:
 return {"error": "Visual Lab is offline. Open your regular build for your career."}
