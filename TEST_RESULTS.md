2026-10-08 최신 전투불능 제거·아군 통과·ZOC 수정 및 실행 검증: CASUALTY_ZOC_REPORT.md 참고. 과거의 HP0 잔류/모든 점유 칸 통과 금지 규칙은 대체되었습니다.

최신 커서 이동·부대 진형 확인 수정 및 검증은 CURSOR_INSPECTION_REPORT.md 참고. 아래는 이전 적 턴·지형 확장의 기록입니다.

# 실행 테스트 — 적 턴·지형·확대 전장

2026-10-07. Windows / Godot4.5.1 stable / OpenGL Compatibility / NVIDIA RTX4060Ti.

## 실행 결과

| 검사 | 결과 |
|---|---|
| Headless editor import | 통과 |
| test_terrain_ai.gd | PASS, 0 failures |
| test_tactical_turn.gd Headless | PASS, 0 failures, 적 공방2회 |
| test_tactical_turn.gd 실제 OpenGL 정상2배속 | PASS, 0 failures, 적 공방2회 |
| test_default_turns.gd | PASS, 0 failures, 기본6vs6 전장 두 적 턴 연속 진행 |
| test_phases.gd | PASS, 0 failures |
| test_engagement.gd | PASS, 단일공방/HP 유지 |
| test_tactics.gd | PASS, 0 failures |
| test_formation.gd | PASS, 0 failures |
| test_interaction.gd | PASS, 0 failures |
| test_play_cycle.gd | PASS, 0 failures |
| test_battle_presentation.gd | PASS, 0 failures |
| 실제 전장/거점/경로/적 전투 PNG 직접 확인 | 통과 |

실제 출력은 verification_tactical.log입니다. 기본 전장의6개 적은1턴과2턴에 각각 enemy1→enemy2→enemy3→enemy4→enemy5→enemy6 순으로 한 번씩 행동했습니다. 점유 중첩/통행불가 목적지 없이 다음 아군 턴으로 넘어갔습니다.

## 첨부 필수20개 시나리오

| 번호 | 확인한 동작 | 근거 |
|---|---|---|
| 1 | 아군 턴에서 실제 선택/이동 후 공격 선택 가능 | tactical_turn 실제 viewport 클릭 |
| 2 | 미행동 부대가 남아도 직접 턴 종료→ENEMY1 | tactical_turn |
| 3 | 현재 공격/저비용 접근 목표 우선; 가까운 주력 선택 | terrain_ai 우선순위, tactical_turn enemy1→player |
| 4 | 적이 실제 인접 헥스 단위로 이동 | tactical_turn 시간별 좌표 관찰, default_turns |
| 5 | 적이 플레이어를 공격 | tactical_turn 공방2회 |
| 6 | Enemy=Attacker/Player=Defender인 실제 BattleScene | tactical_turn Context 검사와 OpenGL PNG |
| 7 | 첫 전투 종료에도 ENEMY1 유지 | tactical_turn 전투 결과 직전/복귀 상태 |
| 8 | 다음 적이 이어서 공격하고 나머지도 이동 | tactical_turn enemy2 두 번째 공방, history5개 |
| 9 | 살아 있는 적 모두 행동 후 PLAYER2/번호 증가 | tactical_turn, default_turns PLAYER2/3 |
| 10 | 숲 비용2가 도달 범위에 반영 | terrain_ai, 실제 경로0→2→4 PNG |
| 11 | 늪 비용3과 숲2의 합5를 예산4로 갈 수 없음 | terrain_ai 가중 corridor |
| 12 | 플레이어 통행불가 경로 제외 | 공통 reachable 물/장애물 검사 |
| 13 | AI도 통행불가/다른 부대 칸 제외, 비용 예산 유지 | terrain_ai 계획, 실제 AI 목적지 검사 |
| 14 | 봉쇄 구간을 남쪽 열린 통로로 우회 | terrain_ai 벽/물 테스트 |
| 15 | 늪 직선보다 긴 저비용 경로 선택 | terrain_ai 누적 최소비용/경로 길이 검사 |
| 16 | 실제 D 키로 큰 맵 보기 이동 | tactical_turn Input.parse_input_event, ScrollContainer 변화 |
| 17 | 아군6/적6 부대 동시 존재 | terrain_ai/tactical_turn 초기12부대, default_turns 전원 행동 |
| 18 | 거점 화면 위치가 실제 hex→pixel 변환과 일치 | tactical_turn point coordinates |
| 19 | PLAYER/ENEMY/NEUTRAL owner와 깃발 구분 | tactical_turn 데이터 검사, 서/중/동 PNG |
| 20 | 씬 전환 후 지형/거점 참조·타입/HP/부대 위치 유지 | tactical_turn terrain snapshot/객체 참조/HP/뷰 위치 검사 |

## 오류와 추가 회귀 검사

적 턴의 플레이어 좌클릭 선택/대기/턴 종료 연타를 차단했습니다. 행동 순서를 history로 검사해 살아 있는 적이 정확히 한 번씩 행동하고 HP0 적이 제외되는 것을 확인했습니다. Enemy 승리에서 플레이어 방어 부대 제거/헥스 점유, 생존 공방의 HP 유지와 Healer 치료도 실제 씬을 통해 확인했습니다.

AI는 봉쇄된 가까운 목표를 버리고 접근 가능한 다른 목표를 선택합니다. 모든 목표가 막히면 현재 위치에서 대기합니다. 즉시 공격 가능한 목표는 추가 이동 목표보다 우선합니다. 두 기본 적 턴의 연속 실행은 적의 moved/acted 초기화와 재행동을 검증합니다.

이전 입력/편성/주력 공격 회귀는 tests/test_interaction.gd와 test_play_cycle.gd의 명시적12×8 평지/4부대 fixture에서 실행합니다. 후자는 적 턴을 수동 완료하는 fixture이며 실제 AI/씬 재개는 별도의 tactical_turn/default_turns가 담당합니다. 기본20×14 전장과 혼동하지 않습니다. 기본/반칸 진형, 최대인원, 저장version1/객체 참조, 우클릭 제거 금지, 드래그 취소, 이동 입력 잠금, 재이동/재공격 차단, 여러 공방 후 승패/HP 유지와 근접/투사체/치료 연출을 회귀 실행했습니다.

## 테스트 환경과 화면

통합 검사는 실제 엔진 InputEvent와 실제 시간을 사용합니다. 물리 마우스 수동 제스처 검사는 아닙니다. OpenGL 검사는 정상2배속으로 적 전투를 연출했습니다. 적 승리 검사를 위해 해당 테스트 프로세스 안에서 두 적을 접촉거리로 배치하고 주력을HP1/다른 멤버0으로 설정했습니다. 다른 한 적은HP0으로 만들어 AI 제외를 검사했습니다. 기본 실행에는 이런 변경이 없습니다.

사용자 실제 저장에 쓰지 않도록 work 하위 별도 APPDATA를 사용했습니다. 테스트 종료 후 다음 실행은 원래 고정 지형/6vs6으로 시작합니다. 최종 로그에서 알려진 SCRIPT ERROR, Parse Error, Invalid Call, Null Instance, 잘못된 씬/리소스 경로, 지형/위치/HP 초기화 오류는 없습니다.

- preview_tactical_west/center/east.png: 실제 큰 전장과3진영 거점.
- preview_terrain_path.png: 숲 경로의 누적 비용0/2/4.
- preview_enemy_battle/result.png: 적 공격측/아군 방어측과 적 승리.
- preview_player_turn2.png: 남은 적 행동 후 아군2턴.

## 재현

프로젝트 폴더에서 godot을 실제 엔진 실행 파일 경로로 바꿉니다.

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_terrain_ai.gd
godot --headless --path . --script res://tests/test_tactical_turn.gd
godot --headless --path . --script res://tests/test_default_turns.gd
godot --headless --path . --script res://tests/test_phases.gd
godot --headless --path . --script res://tests/test_engagement.gd
godot --headless --path . --script res://tests/test_tactics.gd
godot --headless --path . --script res://tests/test_formation.gd
godot --headless --path . --script res://tests/test_interaction.gd
godot --headless --path . --script res://tests/test_play_cycle.gd
godot --headless --path . --script res://tests/test_battle_presentation.gd
godot --path . --script res://tests/test_tactical_turn.gd -- --normal-speed
```

마지막 명령은 전장/거점/적 전투/숲 경로 PNG를 갱신합니다.


전멸 후 위치 유지 후속 검사: test_play_cycle와 test_tactical_turn PASS(0 failures). 이전 점유 기대값을 공격 위치 유지 및 방어 타일 비움으로 수정. 상세 기록 CURSOR_INSPECTION_REPORT.md 참고.

