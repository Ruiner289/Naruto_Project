2026-10-08 최신 전투불능 제거·아군 통과·ZOC 수정 및 실행 검증: CASUALTY_ZOC_REPORT.md 참고. 과거의 HP0 잔류/모든 점유 칸 통과 금지 규칙은 대체되었습니다.

최신 커서 이동·부대 진형 확인 수정 및 검증은 CURSOR_INSPECTION_REPORT.md 참고. 아래는 이전 적 턴·지형 확장의 기록입니다.

# 적 턴·지형·확대 전장 개발 보고

2026-10-07. 기존 Godot 프로젝트를 수정했습니다. 원래 편성/전투/씬을 재사용하고 요청 범위의 전술전만 확장했습니다.

## 1. 기존 Turn 시스템 분석

기존 GameState는 turn 정수와 units의 acted/moved를 관리하고, 모두 행동한 뒤 다음 플레이어 턴 번호를 올렸습니다. 적은 can_act에서 배제되어 AI 턴이 없었습니다. BattleMap은 같은 부대 참조로 이동/공격/대기를 실행하며 BattleContext/BattleScene/BattleResolver가 6단계 단일 공방을 처리했습니다. HexGrid는 이미 Dijkstra를 사용했지만 모든 타일은 비용1인 숫자였습니다.

턴 책임을 TurnManager로 옮기고 GameState.turn은 번호를 읽는 기존 호환 속성으로 유지했습니다. moved/acted의 역할과 사용자가 앞서 요청한 이동 후 공격/대기는 유지했습니다. 이번 직접 턴 종료 요청은 남은 아군 행동을 대기로 처리합니다. GameState가 지형/거점/턴/부대/AI 큐의 소유자로 남습니다.

## 2. 생성 파일

| 파일 | 역할 |
|---|---|
| scripts/data/terrain_definition.gd | 7종 지형 enum, 비용/통행/이름/색/기호 단일 정의 |
| scripts/data/hex_tile_data.gd | 기존 HexGrid가 보유하는 헥스 좌표/지형 데이터 |
| scripts/data/battlefield_setup.gd | 고정 테스트 전장 지형과 3개 거점 배치 |
| scripts/data/control_point_data.gd | ID/이름/헥스/종류/소유자 |
| scripts/battle_map/turn_manager.gd | PLAYER/ENEMY, 번호, 행동 가능 부대, 진영 시작/종료/초기화 |
| scripts/battle_map/enemy_squad_ai.gd | 상태 변경 없는 개별 적 목표/경로 계획 |
| scripts/battle_map/enemy_turn_controller.gd | GameState 자식 Node, 결정적 큐/커서, 이동/공격/전투 후 재개 |
| tests/test_terrain_ai.gd | 지형 비용/장애물/우회/저비용 경로/AI 우선순위/접근 불가 검사 |
| tests/test_tactical_turn.gd | 실제 입력/카메라/적 공격/씬 복귀/나머지 적/다음 아군 턴/거점 상태 검사 |
| tests/test_default_turns.gd | 기본6vs6 전장에서 두 적 턴 연속, 전원1회/점유 중첩/비통행 목적지 검사 |
| verification_tactical.log | 실제 최종 실행 출력 |
| COMBAT_REPORT.md | 이전 병종별 공방 보고 보존 |
| preview_tactical_*.png, preview_terrain_path.png, preview_enemy_*.png, preview_player_turn2.png | 실제 확대 전장/적 전투/경로/복귀 화면 |

## 3. 수정 파일

| 파일 | 변경 |
|---|---|
| scripts/global/game_state.gd | 지형/거점/12부대 초기화, TurnManager/AI 소유, 공통 진영별 행동/탐색/공격 판단, 직접 턴 종료 |
| scripts/global/game.gd | 초기 맵과 전투 복귀 fade 완료 후 적 턴 컨트롤러 재연결/재개 |
| scripts/data/prototype_rules.gd | 기본 맵 크기20×14 단일 설정 |
| scripts/battle_map/hex_grid.gd | 기존 Dijkstra에 지형 정의/통행 검사, 실제 가중 비용, 전체 경로 탐색 예산 추가 |
| scripts/battle_map/squad_map_unit.gd | can_act는 양측 공통 생존/행동 검사; 현재 진영 허용은 GameState |
| scripts/battle_map/hex_board.gd | 큰 보드 크기, 7종 색/기호, 거점 깃발, 누적 경로 비용 |
| scripts/battle_map/battle_map.gd | 현재 진영/ID/지형 UI, 적 턴 입력 잠금, ScrollContainer와 WASD/방향키, 같은 이동 함수 |
| scripts/battle/battle_stage.gd | 실제 진영 색상과 공격측/방어측 제목; 왼쪽=아군 가정 제거 |
| scripts/battle/battle_scene.gd | 진영 중립 승패 문구, 적 턴 복귀 안내 |
| tests/test_interaction.gd, tests/test_play_cycle.gd | 이전 입력/편성 회귀는 별도 작은 평지 fixture로 고정 |
| project.godot | 검증 엔진과 맞게 feature 버전4.5 명시 |
| AGENTS.md, README.md, DEVELOPMENT_REPORT.md, TEST_RESULTS.md, VIDEO_ANALYSIS.md | 현 단계 규칙과 검증 문서 |

기존 SquadData/NinjaData/FormationManager/FormationSlot/HexCoord/BattleContext/Resolver/Animator/씬을 새로 만들지 않았습니다. .gd.uid는 엔진 메타데이터, .godot는 ZIP에서 제외하는 캐시입니다.

## 4. TerrainType 구조

TerrainDefinition.Type은 PLAIN, ROAD, FOREST, SWAMP, MOUNTAIN, WATER, BLOCKED입니다. HexTileData는 Vector2i 헥스와 타입만 소유합니다. HexGrid.tiles의 좌표 키는 유지하고 값은 HexTileData로 확장했습니다. 예전 숫자 비용 기반 작은 테스트 fixture도 호환합니다. 실제 지형은 TerrainDefinition에서 비용과 통행 여부를 읽습니다.

## 5. 지형별 비용

도로/평지1, 숲2, 늪/산3입니다. 물/장애물은 통행 불가입니다. 비용은 TerrainDefinition.DEFINITIONS 한 곳에 있습니다. AI 전체 탐색 예산도 이 정의에서 실제 타일 비용 합을 계산해 얻으며 별도 비용 상수를 복제하지 않습니다. 현재 시작 칸 비용은0이고 다음 타일 진입 비용을 소비합니다.

## 6. 통행 불가 처리

HexGrid.is_passable은 경계와 지형 정의를 검사합니다. Dijkstra의 이웃 확장 전에 물/장애물/점유 칸을 제외합니다. 물이나 장애물을 통과하는 경로는 생성되지 않습니다. 플레이어와 적 모두 같은 함수입니다. 중앙 봉쇄와 동남 물을 실제 전장에 배치했습니다. 공격 대상/거점도 통행 가능한 헥스에 존재합니다.

## 7. Pathfinding

기존 Dijkstra를 확장했습니다. 현재 최소 누적 비용 노드를 꺼내고 6방향 이웃의 진입 비용을 더합니다. cheaper relaxation과 predecessor를 사용합니다. UI 범위, 미리보기, 실제 이동, 적 계획이 같은 결과를 사용합니다. 다른 부대 칸은 양 진영 모두 통과하지 않습니다. 플레이어/AI 탐색을 따로 복제하지 않았습니다.

## 8. 이동 범위와 공격 범위

GameState.search_for는 현재 진영과 moved/acted를 검사하여 남은 이동 예산을 결정합니다. 도달 가능한 cost<=movement 칸만 청록입니다. 이동 후 예산0으로 현재 칸만 남고 그 자리에서 공격/대기를 선택합니다. 주변 공격 영역은 같은 search 결과와 attack_range를 사용하며 이동 후보 밖은 빨강입니다. 목적지 hover는 실제 predecessor 경로, 누적 비용, 남은 예산을 표시합니다. 경로상의 표시값0→2→4를 숲 fixture에서 검증했습니다.

## 9. 확대된 크기와 보기

기본20×14, 총280헥스입니다. PrototypeRules의 MAP_COLUMNS/MAP_ROWS를 HexGrid.width/height로 연결하며 UI 크기/제목도 이 데이터를 사용합니다. 기존 전장이 Control 기반이므로 별도 Camera2D/월드 씬 대신 ScrollContainer 뷰포트로 동일 보드를 이동합니다. WASD/방향키와 스크롤바를 제공합니다. 카메라 밖 부대도 원래 좌표에 존재합니다. GameState.map_scroll은 씬 전환 사이 뷰포트 위치를 유지하고 적 행동 시작 때 해당 적을 화면으로 가져옵니다. 줌은 없습니다.

## 10. 아군 수와 위치

6개입니다. player는 기존 사용자 주력 SquadData 그대로 offset(2,2), ally2는 지원 부대(3,6)입니다. ally3~6은 (2,4),(3,8),(2,10),(3,12)에 있습니다. 추가 부대도 기존 make_squad와 SquadData/FormationSlot을 사용합니다. 최대9명/기본3×3+반칸6개 구조는 유지합니다. 실제 부대장/병종/HP는 기존 테스트 캐릭터 정의를 사용합니다.

## 11. 적군 수와 위치

6개입니다. enemy1(16,2), enemy2(16,6), enemy3~6은 (16,4),(17,8),(16,10),(17,12)입니다. 통행 가능한 서로 다른 칸이며 북/중/남으로 분산되어 있습니다. 이름/ID/진영/부대장은 선택 정보와 적 턴 진행 표시에서 확인합니다.

## 12. Enemy Turn 진행

TurnManager는 PLAYER1→ENEMY1→PLAYER2를 관리합니다. 직접 아군 턴을 마치면 남은 아군 행동을 대기로 처리하고 적의 moved/acted를 초기화합니다. EnemyTurnController는 살아 있고 행동 가능한 적만 큐에 담아 ID 순으로 처리합니다. 현재 index는 행동 전에 증가시켜 씬 전환 후 같은 적이 다시 시작하지 않습니다. 행동 완료한 적은 어둡게 표시됩니다. 모두 마치면 다음 아군 턴 번호를 올리고 아군 상태만 초기화합니다. 매 턴 대상 진영의 모든 생존 행동 기회를 한 번씩 제공합니다.

## 13. 목표 선택

EnemySquadAI는 GameState.search_for의 전체 비용 탐색 결과에서 각 생존 아군 주변의 접근 가능한 공격 위치를 찾습니다. 우선순위는 현재 공격 가능, 이번 이동력 안에서 공격 가능, 나머지 최소 접근 경로 비용입니다. 같은 우선순위에서는 비용, 대상ID 순입니다. 픽셀 거리나 매턴 무작위는 사용하지 않습니다. 접근 가능한 공격 위치가 없는 상대는 제외하고 다른 목표를 검토합니다. 모두 불가능하면 대기합니다.

## 14. 적 이동

계획 경로의 누적 비용이 이동력을 넘기 직전까지의 prefix만 이동합니다. BattleMap.move_unit을 플레이어와 공유하며 매 헥스를 Tween으로 이동합니다. unit.coord는 각 단계 완료 시 갱신됩니다. 다른 부대/지형을 무시하지 않습니다. 화면과 실제 좌표를 따로 순간이동시키지 않습니다. 로그에 적ID/목표/목적지/전체 접근 비용을 출력합니다. 이동 후에는 공통 공격 함수를 다시 검사합니다.

## 15. 적 공격

GameState.attack_route는 공격자와 대상이 서로 다른 진영인지, 둘의 생존/소유 여부와 현재 턴/행동 상태, 공격 가능한 접근 위치를 공통으로 판정합니다. 실제 request_battle은 도착한 현재 칸에서 공격할 수 있을 때만 생성됩니다. Enemy Squad를 Attacker, Player Squad를 Defender로 같은 BattleContext에 연결합니다. 기존 단일6단계/대상예약/오버킬/Healer는 공격 진영과 무관하게 적용됩니다. 전투 화면은 공격자 왼쪽, 방어자 오른쪽이며 실제 아군/적 색상과 제목을 구분합니다.

## 16. 전투 후 Enemy Turn 재개

TurnManager, EnemyTurnController의 queue/cursor, 지형/거점/부대는 GameState에 있으므로 BattleMap 노드가 교체되어도 남습니다. BattleScene은 턴을 변경하지 않고 결과만 적용합니다. Game의 새 맵 fade 완료 후 controller.resume을 호출하여 남은 적부터 진행합니다. 결과에서 복귀 버튼을 누르는 기존 흐름을 유지합니다. 적 턴 중 플레이어 선택/이동/공격/대기/턴 종료와 편성/디버그 변경은 잠그며 전투 속도/결과 확인/맵 보기 이동은 허용합니다.

공격자 승리에서는 진영에 상관없이 방어 부대를 제거하고 그 헥스를 점유합니다. 패배한 공격자는 기존처럼 공격 위치에 HP0으로 비활성화되어 남고 AI 큐에서 제외됩니다. 양측 생존 시 이동한 공격 위치/HP/행동 완료를 유지합니다. 턴/씬 전환이 HP를 초기화하지 않습니다.

## 17. ControlPoint 데이터

ControlPointData는 id, display_name, hex_coord(Vector2i axial), point_type(BASE/OUTPOST/VILLAGE/FORT), owner(PLAYER/ENEMY/NEUTRAL)를 갖습니다. GameState.control_points가 소유하며 HexBoard.center를 통해 실제 헥스 위에 그립니다. 화면 좌표만 저장하지 않습니다. 이름과 진영 깃발을 표시합니다.

## 18. 현재 거점

| ID/이름 | 종류 | 소유 | offset | axial q/r |
|---|---|---|---|---|
| west / 아군 본진 | BASE | PLAYER | (1,7) | (-2,7) |
| center / 중립 전초 | OUTPOST | NEUTRAL | (10,6) | (7,6) |
| east / 적 본진 | BASE | ENEMY | (18,7) | (15,7) |

깃발은 아군파랑/적빨강/중립회색입니다. 현재는 표시용 데이터뿐이며 점령/게이지/생산/회복/보급/수입/거점 승리 조건은 없습니다.

## 19. 실제 실행 테스트

Godot4.5.1 Headless와 실제 NVIDIA OpenGL에서 수행했습니다. terrain_ai, tactical_turn, 기존 phase/engagement/tactics/formation/interaction/player_cycle/presentation 모두 PASS였습니다. 실제 OpenGL 정상2배속 적 공방 두 번→남은 적 이동→다음 아군2턴을 실행했습니다. 별도로 기본6vs6 전장에서 두 적 턴을 연속 실행해6개 적 전원이 턴마다 한 번씩 행동하고 아군2/3턴으로 넘어가는 것을 확인했습니다. 장애물/숲2/늪3/저비용 우회/AI 즉시 공격 우선/접근불가 목표/점유를 검사했습니다. 필수20개 대응표와 명령은 TEST_RESULTS.md, 실제 출력은 verification_tactical.log입니다.

통합 테스트는 적 두 부대를 접촉거리로 옮기고 주력 HP1/나머지 멤버0으로 만들어 적 승리를 확실히 검증합니다. 한 적을 HP0으로 만들어 AI 제외도 확인합니다. 이 fixture는 테스트 프로세스 안에서만 변경하며 기본 전장은 새 실행 시 원래6vs6으로 시작합니다. 이후 별도 숲 표시 fixture를 구성해 누적 비용0/2/4 화면을 확인했습니다. 실제 사용자 저장에는 쓰지 않으며 APPDATA를 work 하위로 격리합니다. 물리 마우스 수동 조작 대신 엔진 InputEvent와 실제 시간/렌더링을 사용하는 자동 검사입니다.

## 20. 발견한 문제와 한계

기존 can_act의 적 제외, 공격 대상의 적군 고정, 화면 왼쪽=아군 가정, 플레이어 턴만 초기화하던 흐름을 수정했습니다. 검증 중 기존 입력 회귀의 작은 평지 맵 가정을 fixture로 분리하고 TurnManager 도입에 맞춰 갱신했습니다. 최종 검사에서 알려진 Parse Error/Invalid Call/Null Instance/잘못된 참조, 적 중복 행동, 적 턴 상태 유실, 타일 관통, 위치/지형/HP 초기화 오류는 없습니다.

현재 전체 전장/턴 저장, 줌, 복잡한 전술 판단/협공/성향/진형 AI는 없습니다. 확정 이동은 되돌리지 않으며 전투 결과 확인 후 복귀 버튼을 누릅니다. 첫 전투 이후 편성은 잠깁니다. AI는 공격 위치에 접근할 수 없으면 대기합니다. 공격 거리1의 단순 접촉이며 시야/장애물 너머 장거리 공격 규칙은 추가하지 않았습니다.

## 21. 임시 규칙과 완료 범위

20×14 지형 배치,6vs6 위치/편성, 이동력4, 공격 거리1, 지형 비용표, 캐릭터 HP/ATK/병종/회복력, 결정적 목표 우선순위는 테스트값입니다. 이번 변경은 기본 적 AI 턴/지형/비용/장애물/확대 전장/부대 수/거점 표시까지입니다. 전략/세계지도/경제/생산/연구/외교/모집/성장/장비/인술/차크라/속성/거점 기능/승리 조건/Fog of War/실제 나루토 그래픽을 추가하지 않았습니다. 요청한 구현과 검증을 마치고 후속 시스템은 추가하지 않습니다.



