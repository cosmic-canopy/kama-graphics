# Gaps found in kama, from building @kama/graphics

What this package hits in kama. Each entry is reduced to the smallest program that shows it and **run** on the version
it names. Never edit `../kama` from here: this file is how kama hears about it, relayed by the owner.

**Current compiler:** kama 0.9.964 (`52032a3b`, kyoten's pin since 2026-11-15), on which the gate is green. GFX-1's
part 1 was built on 0.9.949, part 2 on 0.9.956, part 3 on 0.9.960 to 0.9.964; the package was seeded on 0.9.831
(2026-11-03). What this package hit so far was filed in kyoten's `docs/KAMA_GAPS.md`, where the driving project keeps
them:
- KY-58: nothing reaches the `Shared` holding `this`. Open, kama's KR-395;
- KY-59: an operator released a node passed to it by value twice. Fixed in 0.9.960;
- KY-60: a chained operator's left operand was never freed. Fixed in 0.9.962;
- KY-61: across packages, an operator's result was untyped unless its type was imported. Fixed in 0.9.964;
- KY-62: a generic's type argument inferred from an operator expression was its left operand's type. Fixed in 0.9.964.

Ids are `KGFX-<n>` and are permanent. **Next id: KGFX-1**

## Open

Nothing yet.
