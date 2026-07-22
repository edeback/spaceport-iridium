extends GutTest

## WI-33 shop pricing pure logic (WI-19 followup): ShopTypeData.roll_price clamps
## a malformed band and never goes negative, and stays within [min, max] for a
## well-formed band. Pure - constructed directly, no Global.

func test_roll_price_within_band() -> void:
	# Sample the roll many times; every draw must land inside the band.
	for i: int in 50:
		var price: int = ShopTypeData.roll_price(10, 40)
		assert_between(price, 10, 40, "roll stays within [min, max]")

func test_roll_price_fixed_band() -> void:
	assert_eq(ShopTypeData.roll_price(25, 25), 25, "a zero-width band always returns that price")

func test_roll_price_clamps_inverted_band() -> void:
	# min > max is malformed data; clamp rather than error - hi collapses to lo.
	for i: int in 20:
		assert_eq(ShopTypeData.roll_price(40, 10), 40, "inverted band collapses to the (clamped) min")

func test_roll_price_never_negative() -> void:
	for i: int in 20:
		assert_gte(ShopTypeData.roll_price(-30, -5), 0, "a negative band floors at 0")

func test_min_visit_price_floors_at_zero() -> void:
	var shop_type := ShopTypeData.new()
	shop_type.price_min = -5
	assert_eq(shop_type.min_visit_price(), 0, "negative authored min reads as 0 for the affordability gate")
	shop_type.price_min = 12
	assert_eq(shop_type.min_visit_price(), 12, "a normal min passes through")
