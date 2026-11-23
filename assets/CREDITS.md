# 에셋 출처와 라이선스

`assets/third_party/`는 git에 올리지 않는다 (.gitignore). GegX·Mira Forge 라이선스가 원본 파일 재배포를 금지하고, 이 저장소는 공개라서다.
새 PC에서는 아래 페이지에서 받아 같은 경로에 넣는다. 파일이 없으면 게임은 예전 도형 그림으로 돌아간다 (scripts/art.gd).

| 경로 | 에셋 | 만든 이 | 라이선스 | 받은 곳 |
|---|---|---|---|---|
| third_party/gegx/wizard/ | MAGE Hero Sprite v1.1 (idle_north, idle_south) | GegX | 상업 사용 가능, 출처 표기 불필요, 재배포 금지. AI 생성 후 손질 | https://gegx.itch.io/mage-hero-128 |
| third_party/gegx/enemies/imp_*, acolyte_* | Demons & Cultists Free v1.0 (Imp Scout, Acolyte) | GegX | 같음 (LICENSE_demons_cultists.txt, AI_DISCLOSURE.txt) | https://gegx.itch.io/demons-cultists-free |
| third_party/gegx/enemies/stormharpy_*, staticweaver_* | Free 2 Animated Monsters | GegX | 같음 (LICENSE_free_animated_monsters.txt) | https://gegx.itch.io/free-animated-monsters |
| third_party/miraforge/ | Free Pixel Spell Effects v1.0.3 (64x64 시트 10개) | Mira Forge | 상업 사용 가능, 출처 표기 권장(필수 아님), 재배포 금지 | https://miraforge.itch.io/free-pixel-spell-effects |
| third_party/ninja/ | Ninja Adventure 음악 3곡, 효과음·징글 | pixel-boy & AAA | CC0 | https://pixel-boy.itch.io/ninja-adventure-asset-pack |
| third_party/lentikula/ | Basic Spell Impacts (불·얼음·번개 각 1개) | lentikula | CC0 | https://lentikula.itch.io/freecc0-basic-spell-impacts-sfx |
| fonts/ | Galmuri11 v2.40.4 | Lee Minseo (quiple) | SIL OFL 1.1 (fonts/OFL.txt) | https://github.com/quiple/galmuri |

## 파일 이름 대응 (받은 원본 → 여기)
- Ninja Adventure: Musics/13 - Mystical → music/menu.ogg, 17 - Fight → battle.ogg, 10 - Dark Castle → boss.ogg;
  Jingles/Success1 → sfx/win.wav, GameOver → lose.wav; Sounds/Menu/Accept → click.wav, Cancel → fail.wav;
  Hit & Impact/Hit2 → hit.wav, Impact → castle.wav; Magic & Skill/Magic1 → cast.wav; Bonus/PowerUp1 → upgrade.wav;
  Alert/Alert → boss.wav; Elemental/Explosion → explosion.wav
- lentikula: Fire/Ice/Lightning Spell Impact 1 → fire.wav / ice.wav / lightning.wav
- Mira Forge: effects/<효과>/64x64/<효과>_64x64_sheet.png 그대로
- GegX 몬스터: creatures/.../walk.png, attack.png → <이름>_walk.png, <이름>_attack.png

## 게임 안 크레딧 (출처 표기가 필수는 아니지만 넣는다)
GegX, Mira Forge, pixel-boy & AAA (Ninja Adventure), lentikula, Galmuri (quiple)
