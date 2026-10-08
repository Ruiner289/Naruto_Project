extends Button

var ninja_id: String

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	set_drag_preview(preview)
	return {"ninja_id": ninja_id}
