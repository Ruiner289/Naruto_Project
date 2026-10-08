이 문서는 이전 6단계 공방 수정의 기록입니다. 현재 전술맵·적 턴·지형 상태는 DEVELOPMENT_REPORT.md와 README.md를 기준으로 합니다.

# 이동 후 공격·6단계 공방 개발 보고

2026-10-07. 기존 프로젝트를 수정했으며 새 프로젝트/진형/전략맵을 만들지 않았습니다.

## 1. 분석한 기존 전투 구조

GameState는 FormationManager와 SquadMapUnit 배열을 소유합니다. SquadMapUnit.squad, BattleContext.attacker/defender와 편성 UI는 같은 SquadData를 참조합니다. positions는 캐릭터 ID→FormationSlot이며 current_hp는 부대별 HP입니다. NinjaData는 공유 정의이므로 현재 HP나 소속 부대를 중복 저장하지 않았습니다. 기존 BattleResolver는 속도 순으로 행동 예산을 소비하는 반복 순회였고 BattleScene이 이벤트를 받아 BattleAnimator로 연출했습니다.

기존 맵은 이동 즉시 acted=true로 처리했고 공격 경로 진입 전 좌표를 attacker_origin으로 전달했습니다. 따라서 이동 후 공격할 수 없고 양측 생존 시 이전 좌표로 복귀했습니다. moved와 acted를 분리하고 공격 위치에 도착한 뒤 BattleContext를 생성하도록 수정했습니다.

## 2. 수정 파일과 역할

| 파일 | 변경 및 책임 |
|---|---|
| scripts/data/ninja_data.gd | 기존 데이터에 ClassType, heal_power, 명시적 단계 순서/우선순위/이름 추가 |
| scripts/data/test_roster.gd | 12명에게 임시 병종 지정, 공격 연출 타입과 병종 구분 |
| scripts/data/prototype_rules.gd | 테스트 HP/ATK만 사용, 방어력/속도 공식 제거 |
| scripts/battle/battle_action.gd | 기존 클래스에 예약 행동자/대상/진영/ATTACK 또는 HEAL/값/단계 추가 |
| scripts/battle/battle_resolver.gd | 대상 예약과 실행 분리, 6단계 단일 공방, HP 계산과 종료 책임 |
| scripts/battle/target_selector.gd | 기존 공격 대상 선택 보존, 최소 HP 비율의 부상 생존자 치료 선택 추가 |
| scripts/battle/battle_scene.gd | 단계 제목, 이벤트 로그 출력, Resolver 결과를 기존 Animator에 전달 |
| scripts/battle/battle_animator.gd | 같은 편 치료 대상 표시, 초록 강조/+회복량, 계산 없음 |
| scripts/battle/character_battle_view.gd | 병종 표시와 치료 강조, 표시 HP 유지 |
| scripts/battle_map/squad_map_unit.gd | moved, attack_range, can_move로 이동/행동 분리 |
| scripts/global/game_state.gd | 빈 칸만 이동 후보로 탐색, 후보 주변 공격 범위, 접근 경로, 다음 턴 moved 초기화 |
| scripts/battle_map/hex_board.gd | 청록 이동 범위 우선, 그 밖 공격 가능 영역 빨강 |
| scripts/battle_map/battle_map.gd | 이동 후 공격/대기, 재이동 차단, 현재 공격 위치를 Context로 전달 |
| scripts/battle_map/battle_preview.gd | 새 공방/공격 위치 유지 안내 |
| tests/test_engagement.gd | 기존 반복 예산 검사를 단일 공방/다음 교전 HP 유지 검사로 변경 |
| tests/test_tactics.gd | 속도 대신 단계 우선순위 및 실제 HP 검증 |
| tests/test_interaction.gd | 이동 후 공격 가능, 재이동 차단에 맞춰 기대값 변경 |
| tests/test_battle_presentation.gd | 기존 근접/투사체에 같은 편 치료 연출/중복 계산 방지 검사 추가 |
| tests/test_play_cycle.gd | 이동 범위 밖 공격 영역, 이동→공격 취소/확정, 이동 위치 유지, 여러 턴/승패 검사 |
| README.md, TEST_RESULTS.md, VIDEO_ANALYSIS.md, AGENTS.md | 현재 규칙/조작/검증/유지 원칙 갱신 |

SquadData/FormationManager/FormationSlot/BattleStage/기존 씬/JSON 형식은 재사용합니다. .gd.uid는 엔진 메타데이터이며 .godot 캐시는 ZIP에서 제외합니다.

## 3. 생성 파일과 역할

scripts/battle/battle_logger.gd: 단계 제목과 BattleEvent 결과를 사람이 읽는 문자열로 변환합니다. tests/test_phases.gd: 첨부 프롬프트의 필수 10개 시나리오를 독립적인 테스트 부대로 검증합니다. verification_phase.log: 실제 테스트 출력입니다. 기존 PNG는 현재 화면으로 갱신했습니다.

## 4. 책임 분리

NinjaData는 병종/최대 HP/ATK/회복력 정의, SquadData는 멤버/진형/현재 HP, BattleContext는 양측 실제 부대/발생 위치/공격 위치, BattleAction은 예약, TargetSelector는 선택, Resolver는 계산, Logger는 문자열, Scene/Animator는 재생만 담당합니다. BattleEvent는 기존 호환성을 유지한 결과 Dictionary로 표현하며 동일 역할의 중복 모델을 만들지 않았습니다.

## 5. ClassType과 Phase

NinjaData.phase_order와 get_phase_priority가 Gunpowder→Magic→Ranged→LightMelee→HeavyMelee→Healer 의미를 명시합니다. Resolver.phase는 1~6, phase_history는 시작된 단계입니다. 각 병종은 자신의 단계에서 한 번 행동합니다. 6단계를 한 번 완료하면 winner=2로 종료합니다. 기존 1/2회 예산 데이터 필드는 Resource 호환을 위해 남겨두었으나 현재 공방에서는 사용하지 않습니다. 무한 순회나 자동 2차 공방은 없습니다.

## 6. 같은 단계의 대상 예약

reserve_phase는 양측 살아 있는 해당 병종을 수집하고 모든 BattleAction을 먼저 생성합니다. 이 과정에서는 HP를 바꾸지 않으므로 모두 같은 단계 시작 상태를 봅니다. 공격측 먼저, 방어측 다음, 같은 부대는 전열 열 내림차순→row_offset 오름차순→ID로 재생합니다. 무작위 행동 순서는 없습니다.

## 7. 오버킬

예약에 대상 ID와 target_side를 보관합니다. 실행 때 HP0 대상도 다른 적이 생존하면 그대로 공격합니다. 다음 캐릭터가 새 대상을 찾지 않습니다. 실제 HP는 0에서 제한하고 예약 피해 수치를 이벤트에 남깁니다. 부대 전체가 전멸했으면 이후 공격은 보여주지 않습니다.

## 8. 사망 후 예약 취소와 조기 종료

매 행동 실행 전에 행동자의 현재 HP를 검사하여 HP0이면 예약을 버립니다. next_action은 행동 및 다음 단계 준비 전에 양측 생존자를 검사합니다. 한쪽이 전멸하면 winner=0/1, 예약을 정리하고 이후 단계로 넘어가지 않습니다. 전투불능은 계속 current_hp<=0입니다.

## 9. Healer

PHASE 6 시작 시 살아 있고 최대 HP 미만인 아군만 후보로 잡습니다. HP 비율은 정수 교차 곱으로 비교하고 동률은 ID 순입니다. 자기 자신도 부상한 생존 아군이면 후보입니다. 두 치료자는 같은 대상을 예약할 수 있습니다. 실행은 min(max_hp, current_hp+heal_power)이며 실제 회복량을 이벤트에 기록합니다. 최대 HP까지 찬 예약 대상도 다른 대상으로 바꾸지 않습니다. 죽은 캐릭터를 선택하거나 부활시키지 않습니다. 치료할 사람이 없으면 예약을 만들지 않습니다.

## 10. BattleEvent 구조

Dictionary 필드: side, actor, target_side, target, kind, value, damage, heal, hp, max_hp, phase, action_type. value는 예약된 공격/회복량, damage는 공격값, heal은 최대 HP 제한 후 실제 회복량입니다. action_type은 근접/원거리 화면 표현입니다. 기존 round/actions_left는 호환 필드로 각각 1/0을 유지합니다. 현재 HP는 Resolver만 바꾸며 Logger/Animator는 재계산하지 않습니다.

## 11. 기존 BattleScene 연결과 맵 흐름

Scene은 next_action→로그→Animator.present 순서입니다. 계산된 실제 HP를 화면 카드가 충격 시점에 공개합니다. 단계 시작과 진영/행동자/대상/행동종류/피해 또는 회복량/HP를 콘솔 및 화면 로그에서 확인할 수 있습니다. 즉시 결과도 동일 계산 경로입니다.

맵 이동은 이동력 안의 비점유 칸만 사용합니다. 공격 영역은 도달 가능한 각 칸의 거리 attack_range 이내를 합친 영역입니다. 이동 후보는 청록을 우선하고 그 밖은 빨강입니다. 이동 후 탐색 예산 0으로 현재 위치만 남으므로 공격 범위도 현재 위치 기준으로 축소됩니다. 전장 공격 거리는 임시 1헥스입니다. 이동 전 적 선택을 확정하면 가장 적은 비용의 공격 가능 빈 칸으로 접근합니다.

이동만으로 acted를 소비하지 않습니다. 한 번 이동한 부대는 현재 위치에서 공격 또는 대기할 수 있습니다. 우클릭/취소는 선택/미확정 공격만 취소하여 이미 이동한 목적지를 유지합니다. 공격 완료는 acted=true입니다. 양측 생존/패배 후 BattleContext의 공격 직전 위치를 유지하고, 전멸 승리는 기존대로 적 제거/적 칸 점유입니다. 다음 턴에 moved/acted를 초기화하되 HP는 초기화하지 않습니다. 기본 3×3+반칸6개/최대9명과 적 렌더링 반전은 그대로입니다.

## 12. 실제 테스트 시나리오

첨부의 10개 필수 시나리오: 전체 단계 순서, 동일 적 오버킬, 예약 행동자의 사망 취소, 전멸 시 이후 단계 중단, 치료 HP 비율, 치료자 중복 예약, 최대 HP 제한, 죽은 공격 대상 제외, 죽은 치료 대상 제외, 실제 부대 HP 반영을 실행했습니다. 추가로 단일 공방 종료, 부상 없음 시 치료 생략, 다음 공방 HP 유지, 이동→공격 취소→확정→생존 복귀, 같은 턴 재공격 차단, 다음 턴 반복 공방→전멸 점유, 이동 후 패배 위치 유지, 좌/우클릭/드래그/입력 잠금, 기본/반칸 진형/저장 호환을 검사했습니다.

## 13. 결과

Godot 4.5.1의 Headless 로직/통합 검사와 실제 NVIDIA OpenGL에서 정상 2배속 전체 사이클이 통과했습니다. 실제 OpenGL 근접/투사체/치료 연출 검사도 수행했습니다. 청록/빨강 범위와 결과 PNG를 직접 확인했습니다. 테스트는 엔진 viewport의 실제 InputEvent와 시간을 사용하는 자동 검사이며 물리 마우스 수동 조작 검사는 아닙니다. 사용자 실제 저장 대신 별도 work 하위 APPDATA를 사용했습니다. 상세 결과와 재현 명령은 TEST_RESULTS.md입니다.

## 14. 임시 규칙과 남은 제한

병종 배정과 HP/ATK/회복력/이동력4/전장 공격 거리1은 테스트값입니다. 속도/방어력 공식은 이번 전투에서 사용하지 않습니다. 기존 공격 타깃은 전열→중열→후열, 같은 열은 행동자 row_offset과 가까운 대상/동률ID라는 임시 규칙입니다. 프롬프트에서 Random은 허용 옵션이므로 기존 결정적 TargetSelector를 재사용했습니다. 난수 자체를 사용하지 않아 같은 입력의 결과가 같습니다. 이 병종 배정은 나루토의 최종 능력이나 원작 수치가 아닙니다.

적 AI, 인술, 차크라, 보호, 상태이상, 성장, 장비, 경제, 새 전장/진형, 화려한 연출을 추가하지 않았습니다. 전체 전장/턴 저장은 없고 첫 전투 이후 편성은 잠깁니다. 확정 이동은 되돌리지 않습니다.

## 15. 이후 진형 기반 타깃팅 교체 지점

TargetSelector.choose만 기존 FormationSlot을 읽어 공격 대상을 고릅니다. 이후 보호/병종별 대상 규칙은 이 함수에 연결하면 됩니다. reserve_phase는 선택된 ID를 저장할 뿐이며 HP 계산과 연출에는 진형 보호 규칙을 넣지 않았습니다. 현재 진형 구조와 부대 데이터 참조를 그대로 사용하므로 교체 범위가 명확합니다. 요청 범위의 수정과 검증으로 작업을 마칩니다.

