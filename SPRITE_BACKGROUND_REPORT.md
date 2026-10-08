# 전체 캐릭터 배경 잔여색 정리 — 2026-10-08

현재 연결된 **18종 / 422개 프레임**을 점검하고 재처리했습니다. 대기·이동·공격·원거리 무기·피격·KO를 포함합니다. 팔·다리·무기 사이의 닫힌 틈에 남았던 시트 배경색은 173개 프레임에서 총 2,258픽셀이었습니다.

기존 가장자리 flood-fill은 윤곽선에 둘러싸인 배경색을 그대로 남겼습니다. 실제 시트와 프레임별 색을 비교하여 배경으로 확인한 정확한 RGB key만 투명하게 처리하도록 수정했습니다. 원본 파일은 그대로 보존하고, 배경 key가 아닌 원본 픽셀은 RGB/alpha가 한 픽셀도 바뀌지 않았음을 추출 단계에서 검증합니다. 비슷한 옷 색을 허용 오차로 묶어 지우지 않습니다. 원본 배경 key와 동일한 색을 의도적으로 쓰는 새 시트를 추가할 때는 먼저 수동 색 검토가 필요합니다.

큰낫닌자(generic_scythe)의 피격 셀은 y=162, 높이 54로, KO 셀은 y=317, 높이 57로 수정했습니다. 이전 범위에 섞여 있던 위·아래 동작의 조각을 제외합니다. 애니메이션 프레임 수와 교전 행동 횟수는 유지하며, 발 기준 정렬을 다시 계산했습니다. 낫·봉·철구와 기본 공격 이펙트를 자동으로 작은 조각으로 판정해 지우지 않습니다.

변경: tools/process_sprites.py, 실제 PNG 프레임, data/sprite_profiles/*.json, data/sprite_audit.json. data/sprite_background_cleanup.json에 프레임별 정리 내역이 있습니다. 쿠레나이는 사용자가 선택한 kurenai_sprite.png를 그대로 사용합니다. 전술 입력·저장 편성·능력치·전투 순서는 변경하지 않았습니다.

검증: 원본 전체 SHA-256 일치, 422개 프레임의 배경 key 잔여 0, 독립 조각 후보 0, 배경 key 외 원본 픽셀 일치, 21개 headless 테스트 통과. tests/test_sprite_backgrounds.gd는 실제 Godot가 import한 텍스처의 투명도를 확인합니다. 기본/범용, 추가 6종, 아스마·쿠레나이 실제 OpenGL 교전 테스트도 모두 통과했습니다. 처리 결과: sprite_background_test_results.json / sprite_background_verification.log.

sprite_transparency_review.png는 18종 대표 동작의 체크무늬 투명 배경 검토표이며, sprite_background_before_after.png에는 대표 수정 전후 비교를 담았습니다. 게임 바닥의 타원 그림자는 배경 시트 잔여색과 별도의 기존 표시입니다.
