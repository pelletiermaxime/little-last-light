extends RefCounted


static func api_url() -> String:
	var setting := "leaderboard/dev_api_url" if OS.has_feature("editor") else "leaderboard/api_url"
	return str(ProjectSettings.get_setting(setting, "")).trim_suffix("/")
