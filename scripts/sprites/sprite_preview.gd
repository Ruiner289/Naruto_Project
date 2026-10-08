extends Control

# Independent developer scene: never reads/writes the user's squad or battle.
var stage: BattleStage
var animator: BattleAnimator
var resolver: BattleResolver
var sample: CharacterBattleView
var selection: OptionButton
var info: Label
var running := false
var background := Color(0.04, 0.07, 0.12)

func _ready() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(18, 12)
	add_child(bar)
	selection = OptionButton.new()
	for id in SpriteLibrary.IDS:
		selection.add_item(id)
	bar.add_child(selection)
	selection.item_selected.connect(func(_i): show_sample())
	for state in ["idle", "move", "attack", "hit", "ko"]:
		UIHelpers.button(bar, state, func():
			if sample != null and not running:
				sample.displayed_hp = 0 if state == "ko" else 50
				sample.play_state(state)
				sample.queue_redraw())
	UIHelpers.button(bar, "방향", func():
		if sample != null:
			sample.faces_right = not sample.faces_right
			sample.play_state(sample.visual_state))
	UIHelpers.button(bar, "배경", func():
		background = Color(0.8, 0.8, 0.8) if background.r < 0.5 else Color(0.04, 0.07, 0.12)
		queue_redraw())
	var scenarios := HBoxContainer.new()
	scenarios.position = Vector2(18, 53)
	add_child(scenarios)
	UIHelpers.button(scenarios, "A: 메인 4종 vs 범용 6종", func(): if not running: setup_battle(false))
	UIHelpers.button(scenarios, "B: 범용 vs 범용 (중복 포함)", func(): if not running: setup_battle(true))
	UIHelpers.button(scenarios, "C: 추가 6종", func(): if not running: setup_battle(false, true))
	UIHelpers.button(scenarios, "D: 아스마·쿠레나이", func(): if not running: setup_battle(false, false, true))
	UIHelpers.button(scenarios, "E: 가이반", func(): if not running: setup_battle(false, false, false, true))
	UIHelpers.button(scenarios, "전투 실행", func(): if resolver != null and not running: play_battle())
	UIHelpers.button(scenarios, "개별 프리뷰", func(): if not running: show_sample())
	info = Label.new()
	info.position = Vector2(18, 650)
	add_child(info)
	show_sample()

func clear_views() -> void:
	for node in [stage, animator, sample]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	stage = null
	animator = null
	sample = null
	resolver = null

func show_sample() -> void:
	if running:
		return
	clear_views()
	var id: String = SpriteLibrary.IDS[selection.selected]
	var ninja := NinjaData.new(id, id, 0)
	var squad := SquadData.new()
	squad.positions[id] = FormationSlot.new(2, 1)
	squad.current_hp[id] = 50
	sample = CharacterBattleView.new(ninja, squad)
	sample.displayed_hp = 50
	sample.position = Vector2(570, 300)
	add_child(sample)
	info.text = "프로필별 프레임 / 방향 / 투명 배경 확인 · 개발용 독립 씬"

func setup_battle(generic_only: bool, extended: bool = false, jounin: bool = false, guy_team: bool = false) -> void:
	clear_views()
	var roster := TestRoster.create()
	var ally: SquadData
	if guy_team:
		ally = SquadData.new()
		ally.squad_name = "가이반"
		ally.leader_id = "guy"
		ally.positions = {"guy": FormationSlot.new(2, 0), "lee": FormationSlot.new(2, 2), "neji": FormationSlot.new(1, 0.5), "tenten": FormationSlot.new(0, 1.5)}
		PrototypeRules.ensure_hp(ally, roster)
	elif jounin:
		ally = SquadData.new()
		ally.squad_name = "아스마·쿠레나이"
		ally.leader_id = "asuma"
		ally.positions = {"asuma": FormationSlot.new(2, 0), "kurenai": FormationSlot.new(2, 2)}
		PrototypeRules.ensure_hp(ally, roster)
	elif extended:
		ally = SquadData.new()
		ally.squad_name = "추가 닌자 6종"
		ally.leader_id = "shikamaru"
		ally.positions = {"choji": FormationSlot.new(2, 0), "kiba": FormationSlot.new(2, 1), "hinata": FormationSlot.new(2, 2), "shino": FormationSlot.new(1, 0), "shikamaru": FormationSlot.new(1, 2), "ino": FormationSlot.new(0, 1)}
		PrototypeRules.ensure_hp(ally, roster)
	elif generic_only:
		ally = GenericFactory.make_squad(roster, "preview_a", ["dart", "dart", "claw", "pole", "flail", "scythe"], "범용 아군")
	else:
		ally = SquadData.new()
		ally.squad_name = "메인 닌자 부대"
		ally.leader_id = "kakashi"
		ally.positions = {"kakashi": FormationSlot.new(2, 0), "naruto": FormationSlot.new(2, 2), "sasuke": FormationSlot.new(1, 1), "sakura": FormationSlot.new(0, 1)}
		PrototypeRules.ensure_hp(ally, roster)
	var enemy := GenericFactory.make_squad(roster, "preview_b", GenericFactory.TYPES, "범용 적군")
	var context := BattleContext.new(SquadMapUnit.new("a", ally, HexCoord.new(), false), SquadMapUnit.new("b", enemy, HexCoord.new(1, 0), true))
	resolver = BattleResolver.new(context, roster)
	stage = BattleStage.new()
	stage.position = Vector2(25, 135)
	stage.context = context
	stage.roster = roster
	add_child(stage)
	animator = BattleAnimator.new()
	animator.stage = stage
	add_child(animator)
	info.text = "E: 가이반 vs 범용 6종" if guy_team else "D: 아스마·쿠레나이 (다른 시트 적용)" if jounin else "C: 추가 6종 vs 범용 6종" if extended else ("A: 메인 4종 vs 범용 6종" if not generic_only else "B: 범용 vs 범용 · 서로 독립된 같은 다트병 2명")

func play_battle() -> void:
	running = true
	selection.disabled = true
	while true:
		var event := resolver.next_action()
		if event.is_empty():
			break
		info.text = BattleLogger.format_event(event, stage.roster)
		await animator.present(event, 1.0)
	running = false
	selection.disabled = false
	info.text += " · 한 공방 종료"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), background)
