Goal: Polish and harden systems created in Phase 4.

**Hardening from the 2026-09-18 audits (drafted 2026-09-19).** The findings are in [[03_Bugs_and_Improvements]], the structural argument in [[05_Architecture_Review]], and the ordering in [[02_Roadmap]]:
- [[WI-69_Integration_Test_Fixture]]: the station under test, headless, with its invariants checked after every test.
- [[WI-70_Job_Ownership_Contract]]: the mid-deconstruction save that loses the refund (F38), the stranded build site (F25), and duplicate jobs after every load (F26).
- [[WI-71_Reference_Hygiene]]: one rule for references to nodes you don't own, and the sweeps that hold it.
- [[WI-72_Declared_Vocabularies_And_Content_Guards]]: stat names, content checks, the mod-facing signals and the balance literals.
- [[WI-73_Save_Orchestration]]: the boot and load orderings pinned, and pawn kinds that save themselves.
- [[WI-74_Layering_And_Consolidations]]: one job picker, invalidatable content caches, and the simulation stops calling the HUD.
- [[WI-75_Movement_Without_Coroutines]]: every await in the movement pipeline becomes explicit state, finishing what WI-20 started (split out of WI-71, 2026-09-19).
