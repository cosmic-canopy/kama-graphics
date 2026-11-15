# Gaps found in kama, from building @kama/graphics

What this package hits in kama. Each entry is reduced to the smallest program that shows it and **run** on the version
it names. Never edit `../kama` from here: this file is how kama hears about it, relayed by the owner.

**Current compiler:** kama 0.9.960 (`b39fbaab`, kyoten's pin since 2026-11-15), on which the gate is green. GFX-1's
part 1 was built on 0.9.949, part 2 on 0.9.956; the package was seeded on 0.9.831 (2026-11-03). What this package hit
so far was filed in kyoten's `docs/KAMA_GAPS.md`, where the driving project keeps them:
- KY-58: nothing reaches the `Shared` holding `this`;
- KY-60: a chained operator's left operand is never freed;
- KY-61: across packages, an operator's result is untyped unless its type is imported.

Ids are `KGFX-<n>` and are permanent. **Next id: KGFX-1**

## Open

Nothing yet.
