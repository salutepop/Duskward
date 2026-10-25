# Duskward 리팩토링 계획

## 1. 목표

- 단일 파일에 집중된 로직(`main.gd` 1754줄, `siege_model.gd` 1475줄)을 모듈화하여 유지보수성 향상
- 테스트 통과 상태 유지 (18개 개발자 스위트)
- Godot 4.6.3 standard 호환성 유지
- 기존 facade 경로를 유지한 채 점진적 분리로 회귀 리스크 최소화

## 2. 현황 분석

| 파일 | 줄 수 | 역할 |
|------|-------|------|
| `scripts/main.gd` | 1754 | 렌더링/UI/입력/생명주기/사운드 |
| `scripts/siege_model.gd` | 1475 | 시뮬레이션/전투/경제/체크포인트 |
| `scripts/art.gd` | 269 | 일러스트/시각 효과 |
| `scripts/qa_autoplay.gd` | 412 | QA 자동 플레이 컨트롤러 |
| `scripts/ui_copy.gd` | 16 | UI 카피 |

## 3. 사전 분석 결과

- `siege_model.gd` 내부는 경제/적AI/보스/체크포인트/RNG가 한 파일에 혼재
- `main.gd`는 입력/렌더링/UI/오디오가 한 파일에 혼재
- 테스트는 `res://tests/*` 경로로 호출되며, `SiegeModel` 클래스 이름을 직접 참조하지 않는 한 파일 이동만으로는 테스트 경로가 깨지지 않음
- `tools/run-tests.sh`는 `godot --headless --path . --script res://tests/<suite>.gd` 형태로 실행

## 4. 리팩토링 단계

### Phase 1: 시뮬레이션 모델 분리 (siege_model.gd)

**목표**: `siege_model.gd`를 도메인별로 분리하되, 기존 `SiegeModel` 클래스는 facade로 유지

**구조**:
- `models/combat_stats.gd` — `derived_stats`, `mitigation`, 능력치 계산
- `models/checkpoint_store.gd` — 저장/로드/스키마 4
- `models/rng_manager.gd` — 3개 RNG 생성/시드 관리
- `models/combat.gd` — 데미지/대상선택/투사체/효과
- `models/economy.gd` — 골드/구매/판매/레시피
- `models/enemy_ai.gd` — 적 상태/행동/움직임
- `models/boss_logic.gd` — 보스 패턴/코어/강화
- `models/siege_model.gd` — 기존 파일을 facade로 유지, 내부 구현을 위임

**마이그레이션 순서**:
1. `combat_stats.gd` 추출 — `derived_stats`, `mitigation` 정적 함수 이전
2. `rng_manager.gd` 추출 — RNG 3개 생성/시드 로직 이전
3. `checkpoint_store.gd` 추출 — JSON 저장/로드 이전
4. `combat.gd` 추출 — 데미지/투사체/효과 이전
5. `economy.gd` 추출 — 구매/판매/레시피 이전
6. `enemy_ai.gd` 추출 — 적 AI 이전
7. `boss_logic.gd` 추출 — 보스 로직 이전
8. `siege_model.gd`를 각 모듈 위임 facade로 전환

**검증 포인트**: 각 단계 후 `./tools/run-tests.sh` 실행, 실패 시 즉시 롤백

### Phase 2: UI/입력 분리 (main.gd)

**목표**: `main.gd`를 관심사별로 분리하되, 메인 scene은 기존 노드 구조 유지

**구조**:
- `ui/hud.gd` — HUD/상태 표시
- `ui/shop_ui.gd` — 상점/장비 카탈로그 UI
- `ui/pause_menu.gd` — 일시정지/재개
- `input/touch_controls.gd` — 터치 조이스틱/스킬 버튼 처리
- `input/desktop_controls.gd` — 키보드 입력 처리
- `rendering/arena_renderer.gd` — 아레나/캐릭터 렌더링
- `audio/sfx.gd` — 사운드 효과

**마이그레이션 순서**:
1. `sfx.gd` 추출 — 사운드 재생 로직 이전
2. `touch_controls.gd` / `desktop_controls.gd` 추출 — 입력 처리 이전
3. `hud.gd` 추출 — HUD 업데이트 이전
4. `shop_ui.gd` 추출 — 상점 UI 이전
5. `arena_renderer.gd` 추출 — 렌더링 로직 이전
6. `pause_menu.gd` 추출 — 일시정지 로직 이전
7. `main.gd`를 위임 facade로 전환

**검증 포인트**: 각 단계 후 `./tools/run-tests.sh` + 에디터 실행 확인

### Phase 3: 공통 유틸리티 추출

- `utils/vector_utils.gd` — 벡터/투영/역투영 헬퍼
- `utils/time_utils.gd` — 시간/카운트다운 포맷
- `data/balance_loader.gd` — `data/balance.json`, `tempo_profile.json` 로딩

### Phase 4: 테스트 업데이트

- 기존 테스트 스위트는 facade 경로를 통해 동작하므로 변경 없음
- 분리된 모듈에 대한 헤드리스 단위 테스트 추가 검토
- `tools/run-tests.sh` 경로 불필요 (기존 `res://tests/*` 유지)

## 5. 제약사항

- Godot 4.6.3 standard (GDScript) — `class_name`, autoload, `@icon` 사용 가능
- 헤드리스 테스트 호환성 유지
- Android export 호환성 유지
- 런타임 성능 저하 없음 (모바일 타겟)
- `.godot/` import cache는 리소스 경로 변경 후 `--editor --import --quit`로 갱신

## 6. 우선순위

1. Phase 1 (시뮬레이션 모델) — 가장 복잡하고 버그 위험이 높은 부분
2. Phase 2 (UI/입력) — 사용자 경험에 직접 영향
3. Phase 3 (유틸리티) — 중복 코드 정리
4. Phase 4 (테스트) — 지속적 검증

## 7. 성공 기준

- 각 Phase 완료 후 `./tools/run-tests.sh`가 exit 0
- 파일별 줄 수 감소: `siege_model.gd` 1475줄 → 500줄 이하, `main.gd` 1754줄 → 800줄 이하
- 복잡도: 단일 함수 100줄 초과 금지 (검토 시)
- Android APK 재빌드 가능

## 8. 리스크 및 대응

| 리스크 | 대응 |
|--------|------|
| Godot GDScript 모듈 제약 | `class_name` + autoload로 의존성 명시적 관리 |
| 대규모 리팩토링 회귀 | 단계별 분리 + 각 단계 후 테스트 + Git 커밋 |
| 테스트 경계 깨짐 | facade 유지로 기존 `res://tests/*` 경로 보존 |
| import cache 불일치 | `godot --editor --import --quit` 실행 후 검증 |
| 성능 저하 | 프로파일링 전/후 비교 검토는 별도로 진행 |

## 9. 참고: 기존 아키텍처

- `scripts/siege_model.gd`: authoritative deterministic-seeded simulation
- `scripts/main.gd`: landscape rendering/UI, multitouch input, pause/lifecycle
- `scripts/art.gd`: illustration integration, procedural visual effects
- `data/balance.json`: unchanged original data catalog
- `data/tempo_profile.json`: active separately versioned experimental profile

