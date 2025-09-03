
Some modules consume power. If they don't have power, they don't function. (Where function could be a lot of things)
- Hallways need power for light
- O2 generators need power for O2

Some modules consume power plus inputs over time
- Hydroponics Bay needs power plus biomass to produce food over time

Other modules consume bursts of power when needed, and require a capacitator to hold a charge
- Teleporters use a burst of energy when teleporting
- Replicators use a burst of energy when producing food

Some modules produce power

Some modules consume _and_ produce power
- Batteries
	- Supply all other modules, then if excess power: charge
	- If power required, produce power (draining battery)

Strategy:

Super simple:
- Add up all production
- Add up all consumption
- If production > consumption great, all powered
- Extra power goes to batteries
- If consumption > production
	- If needed < battery production, use that
	- if needed > batteries, discharge all and turn off modules from the most power used down

Less simple:
- Iterate producers
	- Flood fill from producers, filling demand on a per-module basis until all are filled
- If all filled, extra goes to batteries
- If not filled, flood fill from batteries until they are all discharging
- 