# 쿠레나이 다른 GitHub 시트로 교체 — 2026-10-08

사용자가 지정한 **GitHub에 있는 두 파일 중 다른 파일 `kurenai_sprite.png`**로 쿠레나이 스프라이트를 교체했습니다. 이전 붕대 원피스 시트는 원본 보관만 하며, 쿠레나이 프로필에서 분리했습니다. 생성 이미지는 사용하지 않습니다.

원본: assets/sprite_source/메인캐/유우히 쿠레나이/kurenai_sprite.png. 저장소 커밋 7729052a30ca267422eff07f484c0319cd37597f. 시트의 Stance / Run / Combo 기본 손 공격 첫 3개 / Damage를 확인하여 대기 4·이동 5·공격 3·피격 2·KO 2프레임을 연결했습니다. KO는 넘어짐 → 누운 포즈로 끝납니다. 꽃/환술 효과는 사용하지 않습니다.

초록 바탕은 가장자리와 연결되는 정확한 RGB (0,128,0)만 제거합니다. 신체와 옷의 닫힌 영역 안에 있는 동일 색은 유지합니다. 원본 파일·크레딧·SHA-256은 보존합니다. 240×110 투명 프레임과 발 기준 pivot을 기존 SpriteLibrary / CharacterBattleView / BattleAnimator에 연결했습니다. 전체 적용 범위는 18프로필/422프레임입니다.

변경은 쿠레나이 Sprite 프로필·추출 도구·감사 메타데이터·개발 미리보기 설명입니다. 저장 편성, 능력치, 전술 이동, 공격 메뉴 및 교전 규칙은 유지됩니다. 쿠레나이의 기존 로스터 ID를 사용하므로 이미 편성한 쿠레나이도 새 모습으로 표시합니다.

검증: tests/test_jounin_sprites.gd에서 실제 타격 시점 HP 반영, 공격 후 원위치·방향 복구, KO 마지막 포즈 유지 및 다른 시트 연결을 검증합니다. 전체 테스트 결과는 kurenai_swap_test_results.json, 실제 GUI 검증은 kurenai_swap_verification.log, 화면은 sprite_jounin_idle.png / sprite_kurenai_melee.png / sprite_jounin_ko.png에 있습니다.
