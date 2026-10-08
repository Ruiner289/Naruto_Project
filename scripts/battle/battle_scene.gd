extends Control

signal return_requested
var resolver: BattleResolver
var stage: BattleStage
var animator: BattleAnimator
var speed: float = 1.0
var skip: bool = false
var finished: bool = false
var returning: bool = false
var title: Label
var log_label: Label
var result_label: Label
var return_button: Button
var skip_button: Button
var log_lines: Array[String] = []
var logged_phases: int = 0

func _ready() -> void:
	if GameState.battle == null:
		UIHelpers.label(self, "전투 정보가 없습니다.")
		return
	resolver = BattleResolver.new(GameState.battle, GameState.formation.roster)
	var box := UIHelpers.layout(self)
	box.add_theme_constant_override("separation", 8)
	var toolbar := HBoxContainer.new()
	box.add_child(toolbar)
	title = UIHelpers.label(toolbar, "부대 대 부대", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelpers.button(toolbar, "1x", func(): speed = 1.0)
	UIHelpers.button(toolbar, "2x", func(): speed = 2.0)
	skip_button = UIHelpers.button(toolbar, "즉시 결과", func(): skip = true)
	stage = BattleStage.new()
	stage.context = GameState.battle
	stage.roster = GameState.formation.roster
	box.add_child(stage)
	animator = BattleAnimator.new()
	animator.stage = stage
	add_child(animator)
	log_label = UIHelpers.label(box, "공격측 공격 → 방어측 반격 → 공격측 치료 → 방어측 치료")
	log_label.custom_minimum_size.y = 72
	result_label = UIHelpers.label(box, "자동전투 진행 중…", 18)
	return_button = UIHelpers.button(box, "헥스 전장으로 복귀", return_to_map)
	return_button.disabled = true
	call_deferred("play")

func play() -> void:
	while is_inside_tree():
		var event := resolver.next_action()
		while logged_phases < resolver.phase_history.size():
			var wave: Dictionary = resolver.wave_history[logged_phases]
			print("[", "공격측" if wave.side == 0 else "방어측", " · ", BattleLogger.phase_label(wave.phase), "]")
			logged_phases += 1
		if event.is_empty():
			break
		var side_label := "공격측" if event.side == 0 else "방어측"
		var action_label := "치료" if event.kind == BattleAction.Kind.HEAL else ("공격" if event.side == 0 else "반격")
		title.text = "%s %s · %s" % [side_label, action_label, BattleLogger.phase_label(event.phase)]
		var message := BattleLogger.format_event(event, GameState.formation.roster)
		print(message)
		log_lines.append(message)
		if log_lines.size() > 3:
			log_lines.pop_front()
		log_label.text = "\n".join(log_lines)
		if not skip:
			await animator.present(event, speed)
		else:
			stage.refresh_hp()
			await get_tree().process_frame
	finished = true
	title.text = "공방 종료 · 공격 / 반격 / 치료 완료" if resolver.winner == 2 else "공방 종료 · %s PHASE %d에서 전멸" % ["공격측" if resolver.acting_side == 0 else "방어측", resolver.phase]
	return_button.disabled = false
	skip_button.disabled = true
	result_label.text = ["공격측 승리 — 방어 부대 제거. 공격 위치를 유지합니다.", "방어측 승리 — 전멸한 공격 부대를 전장에서 제거합니다.", "공방 종료 — 양측 생존. 공격 위치를 유지합니다."][resolver.winner]
	if not GameState.turn_manager.is_player_turn():
		result_label.text += "  복귀 후 나머지 적이 행동합니다."
	result_label.text += "  HP는 유지됩니다."

func return_to_map() -> void:
	if not finished or returning:
		return
	returning = true
	GameState.apply_battle_result()
	return_requested.emit()
