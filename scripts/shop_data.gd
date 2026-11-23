class_name ShopData
extends RefCounted
## 상점 상품·스킨·출석 보상 정의. 지급은 GameState.grant(). 데모는 테스트 결제 (실제 결제 없음).
## 나중에 Google Play 결제로 바꿀 때 상품 id를 그대로 Play Console 상품 id로 쓴다.

## 현금 상품: id → {title, desc, price(원), gems, stones, skin, once}
const PRODUCTS := {
	"gems_100": {"title": "룬 수정 100", "desc": "", "price": 1200, "gems": 100},
	"gems_550": {"title": "룬 수정 550", "desc": "+10% 보너스", "price": 5900, "gems": 550},
	"gems_1200": {"title": "룬 수정 1,200", "desc": "+20% 보너스", "price": 12000, "gems": 1200},
	"starter": {"title": "스타터 팩", "desc": "수정 300 + 마력석 1,000 + 불꽃 마법사 스킨", "price": 3900,
		"gems": 300, "stones": 1000, "skin": "flame", "once": true},
	"pass": {"title": "마법사의 서약 (30일)", "desc": "즉시 수정 300 + 30일간 매일 수정 60", "price": 5900,
		"gems": 300, "pass_days": 30},
}

## 수정으로 사는 것: id → {title, cost(수정), stones}
const EXCHANGE := {
	"stones_300": {"title": "마력석 300", "cost": 50, "stones": 300},
	"stones_1000": {"title": "마력석 1,000", "cost": 150, "stones": 1000},
}

const CONTINUE_COST := 30  # 이어하기
const DOUBLE_COST := 20  # 보상 2배
const PASS_DAILY := 60
const STARTER_HOURS := 72
const STARTER_AFTER_STAGE := 3  # 이 스테이지 첫 클리어 때 스타터 팩 등장

## 스킨: id → {title, cost(수정, 0=기본, -1=팩 전용), hue, sat, val}  (마법사 그림 색 변형)
const SKINS := {
	"default": {"title": "보랏빛 견습생", "cost": 0, "hue": 0.0, "sat": 1.0, "val": 1.0},
	"flame": {"title": "불꽃 마법사", "cost": -1, "hue": 0.27, "sat": 1.1, "val": 1.05},
	"frost": {"title": "서리 마법사", "cost": 200, "hue": -0.17, "sat": 1.0, "val": 1.1},
	"forest": {"title": "숲의 마법사", "cost": 200, "hue": -0.42, "sat": 0.9, "val": 1.0},
	"gold": {"title": "황금 대마법사", "cost": 500, "hue": 0.37, "sat": 1.2, "val": 1.25},
}
const SKIN_ORDER := ["default", "flame", "frost", "forest", "gold"]

## 출석 7일 주기: [마력석, 수정]
const DAILY := [[50, 0], [0, 10], [100, 0], [0, 20], [150, 0], [0, 30], [0, 80]]

static func price_text(won: int) -> String:
	var s := str(won)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "₩" + s + out
