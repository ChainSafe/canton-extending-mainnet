# Planning

Phase-based work plan for the Extending Mainnet implementation, designed from **current
Splice** (0.6.x, CIP-104 traffic-based app rewards live on MainNet) as if no prior work
existed. The previous plan (`legacy/extending-mainnet-work-plan.md`) is a frozen snapshot of the
WS1/WS2 era; `reconciliation.md` maps its issues onto this plan.

## Layout

| File | Purpose |
|---|---|
| `phase-2.md` | Phase 2 milestone: goal, scope, exit criteria, epic index, sequencing |
| `phase-3.md` | Phase 3 milestone: same shape, design-level |
| `phase-2-epics/P2-E*.md` | One file per Phase-2 epic; leaf issues inline, ready to file |
| `phase-3-epics.md` | Phase-3 epics with leaf sketches (refined when P3 design starts) |
| `reconciliation.md` | Existing issue → new plan item → disposition |

## Conventions

- IDs are stable slugs: epic `P2-E3`, leaf `P2-E3.2`. When filed on GitHub, the mapping
  slug → issue number is recorded in the epic file header and the leaf gets the slug in
  its title, e.g. `[P2-E3.2] Buy-gate fee enforcement`.
- Each epic file body above the `---` is the epic issue body; each `##` section below it
  is one leaf issue body, filed as a sub-issue of the epic.
- Leaf bodies carry: Context, Deliverable, Acceptance, Depends on, Phase-3 foundation
  (where the design deliberately leaves a socket for Phase 3), Refs (FR rows from the
  design doc's Functional Requirements table; design-doc sections; CIP).
- Phase labels follow the settled scope (2026-08-17): Phase 2 = burn CC at gsync rates +
  flat platform fee + governance discount + consumption reporting. App rewards,
  pricing tiers, discount curves, staking, and the org cap are Phase 3.
