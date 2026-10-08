# 커서 이동과 부대 진형 확인 수정

2026-10-07 · Godot 4.5.1 / GDScript. 기존 프로젝트를 이어서 수정했습니다.

## 영상 참고와 적용

제공한 20.67초 영상에서 커서 타일의 노란 모서리 표식, 카메라 위치 변화, 적 이동/공격 범위와 진형 화면을 프레임으로 확인했습니다. 정확한 클릭 간격이나 원작 카메라의 내부 동작은 프레임만으로 확정하지 않았습니다. 사용자가 요청한 커서 이동과 첫 클릭 범위·다음 클릭 진형 방식을 구현했습니다.

- 휠 스크롤 대신 전장 가장자리 커서 이동. 28px 가장자리, 480px/s, 대각선 속도 정규화, 맵 경계 제한. 옆 정보창에서 정지. WASD/방향키 유지.
- 노란 헥스 모서리 커서. 부대 위에도 표시하며 카메라 이동 뒤 같은 포인터 아래 타일을 다시 계산. 지도 밖/확인 창에서 숨김.
- 아군·적 모두 첫 클릭으로 선택/범위, 같은 부대 재클릭으로 진형 확인. 시간 제한 없는 연속 선택 방식.
- 적은 아군 턴에 다음 행동의 전체 이동력으로 범위를 확인. 확인이 HP/위치/행동/전투 상태를 변경하지 않음.
- 진형 확인은 기존 SquadData/FormationSlot 참조 사용. 적 좌우 반전은 그리기만 적용. 기존 편성 편집창은 편집 기능 유지.
- 아군 선택을 공격 명령 부대로 기억한 뒤 적을 선택하고 명시적 공격 버튼으로 미확정 전투 창을 연다. 접근 이동과 최종 전투 시작은 기존 규칙 사용. 범위 밖/행동 완료/적 턴/확인 창 중 공격 불가.
- 우클릭/Esc로 진형 또는 미확정 전투를 닫으면 선택 유지, 다시 취소하면 선택 해제. 확정 이동/전투를 되돌리지 않음.

## 주요 파일

| 파일 | 변경 |
|---|---|
| scripts/battle_map/battle_map.gd | 커서 카메라, 휠 차단, 두 단계 부대 클릭, 공격 버튼, 확인 창 |
| scripts/battle_map/hex_board.gd | 커서 타일 판정, 범위/부대 재생성 시 커서 보존 |
| scripts/battle_map/hex_cursor.gd | 노란 모서리 표식과 밝기 변화 |
| scripts/battle_map/squad_inspector.gd | 양측 읽기 전용 진형 창 |
| scripts/ui/formation_board.gd | 편집 유지, 읽기 전용 데이터와 화면 반전 지원 |
| scripts/global/game_state.gd | 확인용 적 범위 계산, 진형 창 중 턴 종료 방지 |
| tests/test_cursor_inspection.gd | 카메라/커서/첫·두 번째 클릭/취소/읽기 전용 검사 |
| tests/test_interaction.gd, test_play_cycle.gd, test_tactical_turn.gd | 새 클릭 방식에 맞춘 회귀 시나리오 |

## 실행 검증

Godot 4.5.1에서 다음 검사 통과:

- test_cursor_inspection.gd: headless와 OpenGL 실제 화면에서 PASS, 0 failures. 네 방향 가장자리 이동, 고정 커서 타일 갱신, 좌우 경계, 정보창/적 턴/진형 창 정지, 휠 차단, 커서 겹침 순서, 양측 클릭, 읽기 전용, 우클릭/Esc, 상태 보존.
- test_interaction.gd: PASS, 0 failures. 실제 입력, 선택/경로, 미확정 공격 취소, 이동 중 입력 방지.
- test_play_cycle.gd: PASS, 0 failures. 편성 수정, 이동 후 명시적 공격, 다턴 재교전, 전투 후 위치/HP 유지, 전멸 점유, 패배.
- test_tactical_turn.gd: PASS, 0 failures; 적 전투 2회. 적 턴 큐와 전투 복귀/다음 턴/지형 비용 유지.
- test_default_turns.gd, test_terrain_ai.gd, test_formation.gd: PASS, 0 failures.
- test_ui.gd: OpenGL에서 UI 입력과 15개 편성 후보 판정 PASS.

검사는 격리된 APPDATA를 사용했으며 사용자의 저장 파일은 변경하지 않았습니다. preview_cursor_hex.png, preview_enemy_ranges.png, preview_ally_formation.png, preview_enemy_formation.png는 실제 OpenGL 실행에서 저장하고 확인한 화면입니다.

이전 적 턴/지형 개발의 상세 기록은 DEVELOPMENT_REPORT.md, TEST_RESULTS.md에 유지합니다. 최신 입력은 README.md와 이 문서를 기준으로 합니다.

## 후속 수정: 공격 클릭과 적 정보 확인 충돌

공격 가능한 아군 선택 후 적 타일을 클릭해도 적 선택만 되는 문제가 있었습니다. on_hex_clicked에서 합법적인 공격 경로 판정을 적 범위/진형 선택보다 먼저 처리하도록 수정했습니다. 미확정 공격 중 선택은 공격 아군으로 유지하며 취소 후에도 같은 아군으로 다시 공격/이동할 수 있습니다.

아군 미선택/행동 완료/공격 불가일 때 적 범위·진형 확인을 유지합니다. 이미 선택한 적을 다시 클릭할 때는 기억된 공격 부대 때문에 공격으로 전환하지 않고 진형을 표시합니다. 이동 완료 부대는 현재 위치의 공격 범위만 적용합니다. 기존 공격 버튼은 보조 경로로 남았으며 공격 타일 클릭에 필수적이지 않습니다.

test_attack_click.gd, test_interaction.gd, test_play_cycle.gd, test_cursor_inspection.gd 모두 Godot 4.5.1 headless에서 PASS(0 failures). test_attack_click.gd는 OpenGL 실제 입력 검사도 PASS. 접근 가능한 적 클릭, 이동 후 인접 공격, 취소 시 아군 유지, 행동 완료/범위 밖 공격 차단, 아군 미선택 및 적 재클릭 진형을 검사했습니다. 본 절의 공격 우선 동작이 앞선 최초 구현의 설명보다 우선합니다.

## 후속 수정: 전멸 후 공격 위치 유지

GameState.apply_battle_result의 승리 시 방어 타일 점유 처리를 제거했습니다. 승리/패배/양측 생존 모두 BattleContext.attacker_origin(접근 이동 후 공격 시작 위치)을 유지합니다. 승리하면 방어 부대만 제거하고 방어 타일은 빈칸으로 남습니다. 양 진영에 같은 규칙을 적용합니다. HP와 행동 완료 상태는 유지하며 추가 이동을 제공하지 않습니다.

Godot 4.5.1 headless에서 test_play_cycle.gd PASS(0 failures), test_tactical_turn.gd PASS(0 failures; 적 전투 2회). 실제 아군 전멸 승리/적 전멸 승리 후 공격 위치와 빈 방어 타일, 전투 복귀와 HP/행동/적 턴 지속을 검사했습니다. 이전 문서와 검사 기록의 전멸 후 점유 설명은 이 수정으로 대체합니다.
