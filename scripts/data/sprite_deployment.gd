class_name SpriteDeployment
extends RefCounted

const PRESET := "res://data/sprite_deployment.json"
const MARKER := "user://four_teams_deployment_v2.done"

# User-requested replacement once, with a byte-for-byte backup before overwriting.
# Later player edits keep loading normally.
static func prepare(manager: FormationManager, save_path: String = "user://squad.json", marker_path: String = MARKER) -> String:
	if FileAccess.file_exists(marker_path) and FileAccess.file_exists(save_path):
		var error := manager.load_json(save_path)
		return "저장된 부대를 불러왔습니다." if error.is_empty() else error
	var backup_path := ""
	if FileAccess.file_exists(save_path):
		backup_path = save_path.get_basename() + "_before_sprite_deployment_" + str(int(Time.get_unix_time_from_system())) + ".json"
		while FileAccess.file_exists(backup_path):
			backup_path = backup_path.get_basename() + "_copy.json"
		var backup := FileAccess.open(backup_path, FileAccess.WRITE)
		if backup == null:
			manager.load_json(save_path)
			return "기존 편성을 백업하지 못해 재배치를 적용하지 않았습니다."
		backup.store_buffer(FileAccess.get_file_as_bytes(save_path))
		backup.flush()
		if backup.get_error() != OK:
			manager.load_json(save_path)
			return "편성 백업 쓰기에 실패해 재배치를 적용하지 않았습니다."
		backup.close()
	var error := manager.load_json(PRESET)
	if not error.is_empty():
		return error
	error = manager.save_json(save_path)
	if not error.is_empty():
		return error
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker == null:
		return "스프라이트 부대를 저장했지만 적용 완료 표시를 저장하지 못했습니다."
	marker.store_string("four_teams_deployment_v2")
	marker.flush()
	if marker.get_error() != OK:
		return "스프라이트 부대를 저장했지만 적용 완료 표시 쓰기에 실패했습니다."
	marker.close()
	return "카카시반·아스마반·쿠레나이반·가이반, 아군 4부대와 적군 4부대로 재배치했습니다." + (" 이전 편성 백업: " + backup_path.get_file() if not backup_path.is_empty() else "")
