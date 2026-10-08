> 후속 사용자 요청으로 쿠레나이를 GitHub의 다른 kurenai_sprite.png로 교체했습니다. 아래는 최초 적용 기록이며 최신 모습·동작은 KURENAI_REPLACEMENT_REPORT.md를 참고하세요.

# 아스마·쿠레나이 스프라이트 적용 — 2026-10-08

[사용자 스프라이트 저장소](https://github.com/Ruiner289/Naruto_Project_Sprite) 새 커밋 `7729052a30ca267422eff07f484c0319cd37597f`의 원본 3개를 보존하고, 아스마와 **닌자 조끼 없는 쿠레나이**의 기본 동작을 적용했습니다.

- 아스마: `메인캐/사루토비 아스마/asuma.png`. Stoped / Run / Y Combo / Hurt·Dead의 기본 동작 사용. 초록 바탕은 가장자리에서 연결되는 정확한 RGB (0,128,0)만 제거합니다.
- 쿠레나이: `메인캐/유우히 쿠레나이/yuhi_kurenai_spritesheet_by_juanshoalmao_dbd37nr-fullview.png`. 붕대형 흰 원피스와 붉은 소매 복장. 원본 RGBA 투명도를 유지하고, 기본 이동·근접 공격·피격·주저앉은 전투불능 포즈 사용. KO 셀 아래의 시트 표식은 범위에서 제외합니다.
- `kurenai_sprite.png`의 조끼 복장은 원본 보관만 하고 프로필에 연결하지 않습니다. 다운로드 폴더의 작은 시트는 사용하지 않습니다.

| 프로필 | 대기 | 이동 | 기본 공격 | 피격 | 전투불능 |
|---|---:|---:|---:|---:|---:|
| asuma | 4 | 5 | 9 | 2 | 3 |
| kurenai | 4 | 6 | 4 | 2 | 4 |

43개 프레임을 추가하여 전체 **18개 프로필 / 426개 프레임**을 제공합니다. 원본 출처·SHA-256·추출 좌표는 data/sprite_audit.json과 data/sprite_profiles/*.json에 기록했습니다. 재생성 도구는 tools/process_sprites.py입니다.

아스마의 기존 로스터 ID에 스프라이트를 연결하고, 쿠레나이를 편성 목록에 추가했습니다. 쿠레나이 능력치는 기존 2등급 프로토타입 수치와 임시 근접 병종을 사용하며 캐릭터 고유 능력 설정이 아닙니다. 저장 편성·주력 초기 배치·전투 규칙은 변경하지 않습니다. 편성 화면에서 두 캐릭터를 넣으면 전투에 스프라이트로 나옵니다. 독립 개발 씬 scenes/sprite_preview.tscn의 **D: 아스마·쿠레나이**에서 확인할 수 있습니다.

실제 BattleResolver / BattleAnimator 교전에서 양쪽 행동, 타격 시점 HP 반영, 원위치·방향 복구, KO 마지막 프레임 유지 검증을 수행했습니다. 다중 포즈 기본 공격도 피해 적용은 기존 교전 행동당 한 번입니다. 인술/환술 시스템이나 추가 공격 횟수는 도입하지 않았습니다.

Godot 4.5.1: 20개 headless 테스트 모두 통과. 실제 OpenGL 화면에서 기본 동작과 전투, KO 검증 통과. 결과: jounin_test_results.json / jounin_verification.log. 화면: sprite_jounin_idle.png / sprite_jounin_melee.png / sprite_kurenai_melee.png / sprite_jounin_ko.png.
