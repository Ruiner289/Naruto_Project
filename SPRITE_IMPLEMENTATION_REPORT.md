# 실제 Sprite 적용 보고서 — 2026-10-08

> 후속 재배치 요청으로 현재 아군/적군 전 부대를 Sprite 멤버로 변경하고 기존 주력 편성은 최초 실행 시 백업 후 한 번 교체합니다. 최신 배치는 SPRITE_DEPLOYMENT_REPORT.md를 참고하세요.

이번 적용은 검토·승인한 우선 10종의 기본 전투 표현입니다. 기존 선공/반격/치료 순서, 피해 계산, 대상 재선택, 전투불능 제외, 이동 취소, 전장 ZOC와 저장 편성은 유지했습니다.

## 1–3. 조사 범위 / 적용 / 미적용

- 저장소: https://github.com/Ruiner289/Naruto_Project_Sprite
- 원본 기준 커밋: `b8cca81729b7bdfcd2ec1c87c1c4201b4dfee508`.
- 파일 메타데이터 조사: 캐릭터 폴더 55개(메인 45 / 범용 10), 시트 63개(PNG 54 / GIF 9). GIF는 조사된 파일 모두 단일 프레임입니다.
- 기본 동작을 개별 프레임으로 검토하고 실제 적용한 대상: 메인 나루토·사스케·사쿠라·카카시, 범용 소리 중갑병·다트병·발톱병·봉술병·철구병·낫병. **10개 프로필 / 218개 PNG 프레임**입니다.
- 나머지 메인 41종 / 범용 4종은 미적용입니다. 전체 개요 조사와 파일 메타데이터 확인을 최종 Animation Mapping 확인으로 간주하지 않았습니다. 기존 로스터 중 시카마루·이노·쵸지·키바·히나타·시노는 기존 카드로 표시됩니다. 원본 저장소에 없는 야마토·아스마도 카드 표시를 유지합니다.
- `data/sprite_audit.json`에 실제 적용 여부와 프레임 목록을 기록했습니다. 기존 SpriteAudit 검토 패키지는 그대로 보존했습니다.

## 4. Animation Mapping

프레임 수와 0부터 시작하는 근접 타격 프레임입니다. 원본 좌표·발 기준점·배경색·FPS·루프 여부는 각 JSON에 있습니다.

| 프로필 | Idle | Move | 기본 공격 | Hit | KO | 타격 프레임 |
|---|---:|---:|---:|---:|---:|---:|
| naruto | 4 | 6 | 4 | 2 | 4 | 2 |
| sasuke | 4 | 6 | 4 | 2 | 4 | 2 |
| sakura | 4 | 6 | 3 | 2 | 4 | 1 |
| kakashi | 4 | 6 | 4 | 2 | 4 | 2 |
| generic_big_sound | 3 | 5 | 5 | 2 | 6 | 3 |
| generic_dart | 4 | 8 | 2 | 1 | 5 | 1 |
| generic_claw | 3 | 3 | 5 | 2 | 2 | 3 |
| generic_pole | 4 | 4 | 4 | 1 | 7 | 2 |
| generic_flail | 6 | 13 | 9 | 2 | 10 | 7 |
| generic_scythe | 4 | 4 | 5 | 2 | 5 | 3 |

- 메인 4종은 원본의 Idle / Running / Combo 1 / Hurt / Knocked Back 줄을 사용했습니다. 사스케 원거리 표현은 별도 Throw Weapon 3프레임(`ranged_attack`, 타격/발사 프레임 2)입니다. 치도리 등의 기술을 사용하지 않습니다.
- 사쿠라는 현행 Healer 역할을 유지합니다. 기본 주먹 공격은 개별 프리뷰에서 확인할 수 있고 실제 치료는 대기 자세 + 기존 치료 표시로 표현합니다.
- 발톱·봉·낫의 Move는 확실한 달리기 줄을 찾지 못해 Idle 프레임 + 위치 Tween을 사용합니다. 다른 동작을 달리기라고 추측해 연결하지 않았습니다.
- 철구는 일반 철구 휘두르기 줄입니다. 별도의 체인·투척 스킬/피해/차크라 시스템을 추가하지 않았습니다.
- 메인 KO 줄은 바닥 자세로 끝나도록 원본 프레임 순서를 역순으로 연결했습니다. 발톱병 KO는 확인된 누운 2자세만 사용합니다.

## 5–6. 배경 제거 / 여러 배경색

각 프레임 ROI의 바깥 테두리에서 시작하는 **4방향 edge-connected flood-fill**로 지정한 정확한 RGB 색만 투명하게 만듭니다. 시트 전체에서 같은 색을 일괄 삭제하거나 색 거리 tolerance로 의상 색을 지우지 않습니다. 테두리와 연결되지 않은 같은 색은 보존합니다.

메인 시트별 녹색/청록색, 범용 시트별 청록색·회녹색·파란색과 시안 구분선을 프로필별로 구분했습니다. 철구 시트의 서로 다른 줄 배경도 색 목록에 명시했습니다. 발 아래 고정 pivot을 240×110 투명 캔버스에 배치하고 2배 nearest 렌더링합니다. 봉 끝이 신발보다 아래로 내려오는 봉술병은 무기 끝 대신 몸/신발 영역으로 발 기준을 잡습니다. 체격 차이는 유지합니다.

원본 63개 전체 SHA-256 일치 확인을 통과했습니다. `assets/sprite_source/.gdignore`로 거대한 원본 시트의 Godot 자동 import를 막았으며 원본 파일 자체를 수정하지 않았습니다.

## 7–8. 처리 도구 / 프로필 / 프리뷰

- `tools/process_sprites.py`: 수동으로 확인한 행/개별 프레임 경계를 재현하는 Pillow 전처리 도구. 원본 해시 검사, 프레임별 flood-fill, 발 기준 정렬, PNG/프로필/리뷰/적용 inventory 생성. 사용하지 않는 이전 생성 프레임만 처리 폴더 안에서 정리합니다.
- 재생성: Python + Pillow 환경에서 `python tools/process_sprites.py`. 이후 Godot 에디터에서 다시 import합니다.
- `data/sprite_profiles/*.json`: 위 10개 프로필. state별 파일·source_rect·source_foot·FPS·loop·배경색, 기본/상태별 방향, scale/pivot, 타격 프레임, 접근/복귀/히트 정지 시간.
- `assets/sprite_processed/<id>/`: 처리된 218개 프레임. `assets/sprite_processed/review/`: 상태별 리뷰 이미지와 처리 결과 JSON.
- Godot에서 `scenes/sprite_preview.tscn`을 열고 **F6**으로 실행하면 독립 프리뷰가 열립니다. 캐릭터/Idle/Move/Attack/Hit/KO/방향/배경 버튼과 테스트 A/B 전투를 제공합니다. 사용자 저장 편성이나 진행 중인 전투를 변경하지 않습니다.

## 9–10. Godot 변경 파일 / CharacterBattleView

- `scripts/sprites/sprite_library.gd`: JSON을 읽어 Texture/SpriteFrames를 프로필별 공유·캐시합니다. 파일/프로필이 없으면 카드로 fallback합니다.
- `scripts/sprites/sprite_preview.gd`, `scenes/sprite_preview.tscn`: 개발용 독립 프리뷰.
- 기존 `scripts/battle/character_battle_view.gd`: AnimatedSprite2D, nearest, 방향, 발 pivot, 상태 재생, HP/이름/피해 숫자 표시. 기존 public 속성과 fallback 카드 표현을 유지했습니다.
- `scripts/battle/battle_animator.gd`: 실제 프레임 기반 접근·공격·타격·피격·복귀와 타격 시점 HP 표시.
- `scripts/battle/battle_stage.gd`: 아군 왼쪽/적 오른쪽, render-only 반전 유지, 스프라이트 공간/발 기준 깊이 순서.
- `scripts/battle/battle_scene.gd`: 720p에서 결과·복귀 버튼이 들어오도록 전장 높이/여백/로그 3줄을 조정했습니다. 전체 이벤트는 콘솔 로그로 출력됩니다.
- `scripts/data/ninja_data.gd`: 선택적인 sprite_profile_id 및 전장 전용 인스턴스 구분. 능력·피해 공식은 바꾸지 않았습니다.
- `scripts/data/generic_factory.gd`: 범용 템플릿과 고유 인스턴스 ID 생성.
- `scripts/global/game_state.gd`: 기존 적 제3~6부대에 범용 템플릿을 적용했습니다. 적 선봉/예비와 아군 저장 편성을 유지했습니다.
- `scripts/ui/main.gd`: 적 전장 전용 인스턴스를 플레이어 편성 목록에서 제외합니다.
- 테스트 3개 조정/1개 추가: 고정 시간 대신 타격·종료 signal 확인, 최신 공격측 우선 규칙에 맞춘 옛 테스트 기대값 수정, headless에서 렌더 완료 대기 제거, 실제 Sprite 통합 검사.

`BattleResolver`, `BattleAction`, `TargetSelector`, `SquadData`, `FormationSlot`, 기존 JSON 저장 형식은 이번 작업으로 변경하지 않았습니다.

## 11–13. 공격 / 피격 / KO

근접: Move → 상대 앞 접근 → 기본 공격 → 프로필의 타격 프레임에 계산 완료된 BattleEvent 결과 표시 → 짧은 hit pause/피격 → 공격 동작 마무리 → 반대 방향 Move로 자기 진형 위치 복귀 → Idle. 이 복귀는 **전투 화면 안의 연출**이며 전술맵에서 공격한 타일은 그대로 유지합니다.

원거리: 진형 위치 유지 → 일반 무기 던지기 → 무기 투사체 → 도착 시 HP/Hit 표시 → Idle. 기존 임시 원거리 병종 배정과 피해 계산을 유지했습니다. 치료는 대기 자세와 치료 플래시/회복 숫자를 사용합니다.

논리 HP는 기존 resolver가 계산합니다. 화면 HP는 타격 이전 값을 유지하다 타격/투사체 도착 순간 event.hp로 갱신합니다. 살아 있으면 Hit 후 Idle, HP 0이면 KO를 한 번 재생하고 마지막 자세를 유지합니다. KO 캐릭터는 그 교전 동안만 표시하고 다음 교전 생성 시 제외합니다. 죽은 행동자/대상 제외와 생존 대상 재선택은 기존 resolver 규칙을 유지합니다.

## 14. Generic Character

6개 별도 타입(`big_sound`, `dart`, `claw`, `pole`, `flail`, `scythe`)을 사용합니다. 같은 타입을 여러 번 생성할 수 있으며 각 멤버는 고유 ninja.id / SquadData HP / AnimatedSprite2D 상태를 가집니다. 공유하는 것은 검토된 SpriteFrames/Texture뿐입니다. 전장 제5 적 부대와 테스트 B에 같은 다트병 2명이 있습니다. 임시 병종/기존 테스트 stats를 사용하며 새 스킬이나 다칸 점유 규칙은 없습니다.

## 15. 검증

- 원본 63개 SHA-256 보존 PASS.
- 테두리 색 제거 + 닫힌 내부 동일색 보존 synthetic regression PASS.
- 10개 프로필, state별 frame count/loop, nearest, 캐시, 독립 중복 상태 PASS.
- 실제 애니메이션 테스트 A: 메인 4종 vs 범용 6종, 10개 이벤트 PASS.
- 실제 애니메이션 테스트 B: 범용 vs 범용, 중복 포함, 12개 이벤트 PASS.
- 타격 전 HP 보존 / 타격 시 HP+Hit / 시각적 원위치 복귀 / KO 마지막 프레임 유지 / 다음 교전에서 사망자 제외 PASS.
- 실제 production BattleScene 자동 재생과 1280×720 복귀 버튼 화면 안 배치 PASS.
- headless 전체 16개 테스트 모두 PASS: `sprite_test_results.json`.
- OpenGL/NVIDIA 실제 그래픽 실행 PASS. `sprite_preview_A.png`, `sprite_preview_B.png`, `sprite_preview_impact.png`, `sprite_battle_ingame.png`를 저장하고 검토했습니다.
- 사용자 실제 APPDATA 대신 work/의 독립 APPDATA를 사용했습니다.

## 16–17. 수정한 잘림 / 남은 수동 검토

초기 추출에서 카카시 달리기 경계, 발톱 공격/KO 경계, 철구 KO 행 높이가 부정확해 옆 프레임이나 다음 행 픽셀이 섞이는 사례를 발견하고 수정했습니다. 봉술병의 무기 끝이 발 pivot으로 잡히던 사례도 신발 기준으로 수정했습니다. 최종 검토 이미지와 실제 전투에서 우선 10종의 명백한 옆 프레임 혼입이나 의상색 일괄 소실은 확인하지 못했습니다. 모든 미적용 시트의 색/잘림까지 검증했다는 의미는 아닙니다.

달리기 fallback 3종은 정확한 달리기 줄이 확인될 때 교체할 수 있습니다. 아래 미적용 폴더는 캐릭터별 기본 동작과 무기/배경/방향/발 기준점을 추가 수동 검토해야 합니다. 검토되지 않은 기술 프레임을 기본 공격으로 자동 지정하지 않습니다.

- 메인캐/3대 카제카게(꼭두각시)
- 메인캐/가아라
- 메인캐/나라 시카마루
- 메인캐/데이다라
- 메인캐/도스 키누타
- 메인캐/록 리
- 메인캐/마이트 가이
- 메인캐/사루토비 히루젠
- 메인캐/사소리
- 메인캐/사소리(히루코)
- 메인캐/사콘
- 메인캐/사콘(주인술)
- 메인캐/아부라메 시노
- 메인캐/아키미치 쵸지
- 메인캐/야마나카 이노
- 메인캐/오로치마루
- 메인캐/우즈마키 나루토(구미화)
- 메인캐/우치하 사스케(주인술)
- 메인캐/우치하 이타치
- 메인캐/이누즈카 키바
- 메인캐/자쿠 아부미
- 메인캐/지라이야
- 메인캐/지로보
- 메인캐/지로보(주인술)
- 메인캐/츠나데
- 메인캐/카부토
- 메인캐/칸쿠로
- 메인캐/코난
- 메인캐/키도마루
- 메인캐/키도마루(주인술)
- 메인캐/키미마로
- 메인캐/키미마로(주인술)
- 메인캐/키사메
- 메인캐/킨 츠치
- 메인캐/타유야
- 메인캐/타유야(주인술)
- 메인캐/테마리
- 메인캐/텐텐
- 메인캐/폐인
- 메인캐/휴우가 네지
- 메인캐/휴우가 히나타
- 범용캐/거울닌자
- 범용캐/소리닌자(묶음)
- 범용캐/소리닌자1
- 범용캐/소리닌자2
