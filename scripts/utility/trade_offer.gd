class_name TradeOffer
extends RefCounted

## The arithmetic behind one line of the Trade panel's order table (WI-55),
## lifted out of `trader_screen._build_rows()` before that screen was deleted.
##
## The design's table has **one signed stepper per commodity**, and the sign is
## the direction. That is the point of this class - with two spin boxes per row
## (what shipped in WI-08) nothing stopped both being non-zero, and "buy 5 and
## sell 5 of the same ore in the same visit" was a representable state that the
## fulfilment loop then had to have an opinion about. One int cannot be both, so
## the contradiction stops existing rather than being defended against.
##
## ## What the sign means: **stock, not money**
##
## A line's amount is the change to the station's own holding of that good.
## [b]Positive buys[/b] - units arriving - and [b]negative sells[/b] - units
## leaving. The column is headed by HELD and AVAIL, both counts of goods, so the
## number under them counts goods too and moves the same way they will.
##
## Credits run the other way, and are left to do so: a sell earns (`+ cr`), a buy
## costs (`- cr`), which is what the summary bar's NET reads. One line therefore
## shows `-60` against `+1800 cr`, and that is the sentence "sixty units leave,
## eighteen hundred credits arrive" rather than a contradiction. Do not try to
## make the two agree - they are opposite sides of the same trade, and the panel
## puts them in separate columns precisely so each can be read in its own units.
##
## (WI-55 shipped this the other way round, goods signed like the money. It read
## as "+ is good for me" rather than as a quantity, and inverted every count
## against the two columns beside it.)
##
## Two states share the table:
##
##   - **undocked** - the standing order sheet on the bay's [TradeComponent].
##     Prices are today's market prices and the numbers are a *want*: nothing is
##     committed, so buys are open-ended (the visiting trader's own stock is the
##     real limit at trade time).
##   - **docked** - what is actually possible during this visit. Prices are the
##     visit's snapshot, and every limit is real.
##
## Pure: static, no nodes, no [Global]. The manager state it reasons about
## (trader stock, cargo space, credits, reservations) is passed in.

# --- limits -------------------------------------------------------------------

## Cap on an undocked buy line. Standing orders are not capped by today's market
## (WI-08): the trader who eventually arrives carries whatever they carry, so a
## number here is a want, not a promise. Large rather than unbounded so the
## stepper still has a range.
const ORDER_CAP: int = 9999

## The most this line may be set to SELL, as a positive magnitude - the stepper's
## **negative** end.
##
## `current` is the line's own signed value, so the sell already on it is
## `-current`, and that is what gets added to the available stock. The add-back is
## deliberate, and it is the subtlety that makes the column usable. A sell order
## *causes* the hauls that reserve the stock it is going to sell: the export bin's
## `desired` posts pull jobs, those jobs claim withdrawals in the storerooms, and
## the station's unreserved total drops by exactly the amount already ordered.
## Capping at the bare available figure would therefore ratchet the player's own
## order downward every refresh, one haul at a time. Adding the line back in means
## a line only ever gets clamped by *someone else's* claim - a construction site
## taking the ore - which is the case the column is for.
##
## `cargo_space` is the trader's remaining hold and only applies while docked:
## sold goods physically enter it ([code]TraderManager._fulfill[/code] adds to
## `cargo_used` on the sell side). Pass [constant ORDER_CAP] when undocked.
static func sell_limit(available_unreserved: int, current: int, cargo_space: int) -> int:
	return maxi(mini(maxi(available_unreserved, 0) + maxi(-current, 0), maxi(cargo_space, 0)), 0)

## The most this line may be set to BUY, as a positive magnitude - the stepper's
## **positive** end.
##
## Three real caps while docked: what the trader carries, what the station can pay
## for at the snapshot price, and the room left in the bay's import bin. Note that
## the trader's *cargo hold* is not one of them - a purchase leaves their hold
## rather than filling it; the hold caps sells. (WI-55's own verification list has
## these the other way round; `TraderManager._fulfill` is the authority and this
## follows it.)
##
## A zero or negative price means the goods are free, so affordability is not a
## limit - matching the `price <= 0` branch in the fulfilment loop rather than
## dividing by zero.
static func buy_limit(trader_stock: int, credits: int, unit_price: int,
		import_space: int) -> int:
	var limit: int = maxi(trader_stock, 0)
	if unit_price > 0:
		limit = mini(limit, maxi(credits, 0) / unit_price)
	return maxi(mini(limit, maxi(import_space, 0)), 0)

## Pins a line back inside its limits. `buy` and `sell` are both positive
## magnitudes; the signed result is what the stepper holds, so the buy is its
## upper bound and the sell its lower one.
static func clamp_amount(amount: int, buy: int, sell: int) -> int:
	return clampi(amount, -maxi(sell, 0), maxi(buy, 0))

# --- direction ----------------------------------------------------------------

## Positive buys - goods arriving. Negative sells - goods leaving. Zero is a line
## the player has not set, which is why it is neither: a "no trade" row must not
## be counted in the footer's `n LINES SET`.
static func is_sell(amount: int) -> bool:
	return amount < 0

static func is_buy(amount: int) -> bool:
	return amount > 0

# --- which number a line shows --------------------------------------------------

## The signed amount one sell/buy dictionary pair holds for a line. Two halves is
## the shape everything in this system stores an order in ([TradeComponent]'s
## sheet, [TraderManager]'s commitments); the table's stepper is one signed int,
## and this is the join between them.
static func signed_order(sells: Dictionary, buys: Dictionary,
		resource: ResourceData) -> int:
	if sells.has(resource):
		return -int(sells[resource])
	if buys.has(resource):
		return int(buys[resource])
	return 0

## What one line of the table reads, given every place a number for it could
## live. Three sources in strict precedence, and the order is the whole rule:
##
## 1. [b]pending[/b] - a docked line the player has moved this visit. Docked, a
##    stepper is a proposal, and a proposal is deliberately written nowhere else
##    until `CONFIRM` - so this is the only place it exists, and it has to win.
##    Without it the refresh that follows the player's own edit reads the line
##    back off the orders it was never written to and snatches it to zero, which
##    is exactly the defect this precedence was extracted to fix: the docked
##    table could not be edited at all.
## 2. [b]the visit's commitment[/b] - a line already confirmed this visit,
##    possibly part-fulfilled ([code]TraderManager._fulfill[/code] decrements it
##    and erases it once it is met, at which point the line falls through).
## 3. [b]the standing order[/b] - the bay's sheet, which is the whole answer while
##    undocked and the starting point for a docked line nobody has touched.
##
## `pending` and the commitments are ignored entirely while undocked: both belong
## to a visit, and outside one the sheet is the only truth there is.
static func displayed_amount(resource: ResourceData, docked: bool, pending: Dictionary,
		committed_sells: Dictionary, committed_buys: Dictionary,
		standing_sells: Dictionary, standing_buys: Dictionary) -> int:
	if docked:
		if pending.has(resource):
			return int(pending[resource])
		var committed: int = signed_order(committed_sells, committed_buys, resource)
		if committed != 0:
			return committed
	return signed_order(standing_sells, standing_buys, resource)

# --- pricing ------------------------------------------------------------------

## The price one unit trades at. While docked that is the visit's snapshot, taken
## on arrival so prices hold still for the whole visit (WI-08); otherwise it is
## today's market price, and the total the table shows is a projection rather than
## a quote.
##
## `snapshot` is [TraderManager]'s `buy_prices` / `sell_prices`, keyed by
## [ResourceData]. A docked resource missing from it falls back to the market
## price rather than to zero: a free trade is a money bug, and a resource the
## snapshot never saw is a resource the trader will not stock anyway.
static func unit_price(resource: ResourceData, snapshot: Dictionary, market_price: int,
		docked: bool) -> int:
	if not docked:
		return market_price
	return int(snapshot.get(resource, market_price))

# --- one line -----------------------------------------------------------------

## One commodity row's committed numbers - what the panel builds a row from and
## what the footer totals over. A plain record: the rules are the statics above.
class Line extends RefCounted:
	var resource: ResourceData
	## Signed: positive buys, negative sells - goods, not credits.
	var amount: int = 0
	## What the station pays per unit to buy, and receives per unit to sell.
	var buy_price: int = 0
	var sell_price: int = 0

	static func of(line_resource: ResourceData, line_amount: int,
			buy: int, sell: int) -> Line:
		var line := Line.new()
		line.resource = line_resource
		line.amount = line_amount
		line.buy_price = buy
		line.sell_price = sell
		return line

## Credits this line moves: positive for a sell, negative for a buy, zero for an
## unset line.
##
## The sell side is the **gross**, before the ARC levy skim. `record_income`
## returns the net and the caller banks that (a standing project invariant, and a
## real money-loop bug once) - but that happens at fulfilment, unit by unit, and
## quoting a levied figure here would promise a number the panel cannot know: a
## trader can depart with half an order unfilled.
## Both branches negate, because credits move opposite to goods: units out earn,
## units in cost. Only the price differs between them.
static func line_credits(line: Line) -> int:
	if line == null:
		return 0
	if is_sell(line.amount):
		# amount is negative, so this comes out as the earnings.
		return -line.amount * line.sell_price
	if is_buy(line.amount):
		return -line.amount * line.buy_price
	return 0

## The order's running `NET`, sign-coloured in the footer.
static func net_credits(lines: Array) -> int:
	var total: int = 0
	for entry: Variant in lines:
		total += line_credits(entry as Line)
	return total

static func count_sells(lines: Array) -> int:
	var count: int = 0
	for entry: Variant in lines:
		var line: Line = entry as Line
		if line != null and is_sell(line.amount):
			count += 1
	return count

static func count_buys(lines: Array) -> int:
	var count: int = 0
	for entry: Variant in lines:
		var line: Line = entry as Line
		if line != null and is_buy(line.amount):
			count += 1
	return count

## The footer's summary. A summary rather than a cart because "a 30-line order
## makes a per-item cart unreadable" - the table itself is the itemisation.
static func summary_text(lines: Array) -> String:
	var sells: int = count_sells(lines)
	var buys: int = count_buys(lines)
	return "%d LINES SET · %d SELL · %d BUY" % [sells + buys, sells, buys]

# --- commit -------------------------------------------------------------------
#
# Two dictionaries rather than one signed map, because that is the shape both
# TraderManager.commit_trades and TradeComponent's order sheet already take.

## The sell half of an order, ready for `commit_trades` as the positive magnitude
## it stores. Unset and buy lines are
## absent rather than present-and-zero: the manager erases non-positive entries
## anyway, and an empty dictionary is what "nothing committed" should look like.
static func sell_orders(lines: Array) -> Dictionary[ResourceData, int]:
	var out: Dictionary[ResourceData, int] = {}
	for entry: Variant in lines:
		var line: Line = entry as Line
		if line != null and line.resource != null and is_sell(line.amount):
			out[line.resource] = -line.amount
	return out

## The buy half. Already positive, so it passes through unchanged.
static func buy_orders(lines: Array) -> Dictionary[ResourceData, int]:
	var out: Dictionary[ResourceData, int] = {}
	for entry: Variant in lines:
		var line: Line = entry as Line
		if line != null and line.resource != null and is_buy(line.amount):
			out[line.resource] = line.amount
	return out
