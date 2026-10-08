extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var screen: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	# Isolate drag/drop geometry from the current authored startup roster.
	screen.manager.squad.positions = {"kakashi": FormationSlot.new(2, 0)}
	screen.refresh()
	screen.select_ninja("naruto")
	screen.board.slot_clicked.emit(FormationSlot.new(0, 0.5))
	assert(screen.manager.squad.positions["naruto"].row_offset == 0.5)
	screen.board.ninja_dropped.emit("naruto", FormationSlot.new(0, 1.5))
	assert(screen.manager.squad.positions["naruto"].row_offset == 1.5)
	screen.board.remove_requested.emit("naruto")
	assert(not screen.manager.squad.positions.has("naruto"))
	for col in 3:
		for half in 5:
			var slot := FormationSlot.new(col, float(half) / 2.0)
			assert(screen.board.slot_at(screen.board.slot_rect(slot).get_center()).key() == slot.key())
	print("UI event and 15 hit-target tests: PASS")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview_initial.png")
	var ids := ["naruto", "sasuke", "sakura", "shikamaru", "ino", "choji"]
	for i in 6:
		screen.manager.place(ids[i], FormationSlot.new(i % 3, 0.5 if i < 3 else 1.5))
	screen.select_ninja("naruto")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview_half_slots.png")
	quit()
