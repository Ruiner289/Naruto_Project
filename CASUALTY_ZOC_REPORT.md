# 전투불능·아군 통과·ZOC 수정

2026-10-08 · Godot 4.5.1 / GDScript.

## 변경

- GameState.apply_battle_result: 전멸한 공격/방어 부대를 모두 제거. 생존 공격자는 접근 후 공격 위치 유지. 전멸한 부대의 점유·ZOC·회색 맵 표시를 남기지 않음.
- BattleStage: 교전 시작 시 HP0인 캐릭터의 뷰 생성 생략. 교전 중 새로 전투불능이 된 캐릭터는 기존 뷰로 해당 교전의 결과까지 표시. 다음 교전에서 숨김. FormationBoard의 읽기 전용 진형도 HP0 캐릭터 숨김. 배치 좌표와 기존 데이터 참조 유지.
- PrototypeRules.living_count: 맵 정보/진형 확인의 인원 수를 생존 인원 기준으로 표시.
- HexGrid/GameState.search_for: 적대 부대만 진입 금지. 같은 진영은 경로 중간 노드로 통과 가능하되 목적지 비용 목록에서 제외. 경로 추적과 표시에는 통과 노드의 누적 비용 유지.
- ZOC: 살아 있는 적대 부대의 인접 6칸에서 경로 확장 중단. 시작 타일에는 중단을 적용하지 않으므로 이탈 가능. 다른 ZOC 칸에 들어가면 다시 중단. 아군이 있는 ZOC 칸에서는 멈출 수 없으므로 그 너머까지 통과 불가. 공격/대기는 이동 종료 후 가능.
- EnemySquadAI: 같은 탐색과 통과 비용 사용. 이동력이 끝나는 지점이 아군 타일이면 마지막 빈칸까지 경로를 줄임. 반대 진영 타일과 ZOC 규칙은 동일.
- HexBoard/BattleMap: HP0 부대 표시·선택 제외, 유효하지 않은 선택 제거. 이동 가능한 ZOC는 주황 테두리. BattleScene의 결과 안내도 전멸 제거/공격 위치 유지에 맞게 수정.

이 규칙은 사용자 요청에 따른 프로토타입 규칙이며 특정 SRPG의 내부 공식을 확인했다는 의미는 아닙니다. 이전 개발 문서의 패배 부대 HP0 맵 잔류와 모든 부대 통과 금지 설명은 이 수정으로 대체합니다.

## 검증

격리된 APPDATA에서 Godot 4.5.1 실행:

- test_casualty_zoc.gd: headless/OpenGL 모두 PASS(0 failures). 실제 아군 통과 이동, 아군 도착 불가, 적 점유 차단, ZOC 진입 종료/이탈, 아군이 있는 ZOC 통과 제한, 적 AI의 아군 통과/이동력 경계 빈칸 정지, 이전 전투불능 숨김/이번 전투불능 표시/다음 교전 숨김, 양측 전멸 제거, 제거 후 점유·ZOC 해제.
- test_play_cycle.gd: PASS(0 failures). 여러 턴 공방, 생존/승리 위치 유지, 패배 공격자 제거와 타일 비움. 디버그 회복은 제거된 부대를 부활시키지 않음.
- test_tactical_turn.gd: PASS(0 failures; 적 전투 2회). AI 이동, 전투 후 큐 재개, 다음 아군 턴, 지형 비용 유지, HP0 맵 표시 없음.
- test_default_turns.gd: PASS(0 failures). 기본 6vs6 적 두 턴, 최종 부대 중첩 없음.
- test_terrain_ai.gd, test_attack_click.gd, test_interaction.gd, test_cursor_inspection.gd, test_phases.gd, test_battle_presentation.gd, test_formation.gd: PASS(0 failures).

preview_zoc_movement.png는 통과/ZOC 전용 단일 통로 검사 화면이며 기본 맵 크기는 그대로 20×14입니다. preview_current_casualty.png는 이번 교전에서 쓰러진 캐릭터만 남는 표시 검사 화면입니다. 두 화면은 실제 OpenGL에서 저장하고 확인했습니다.
