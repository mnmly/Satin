# Upstream Sync Log

Tracks each merge of `upstream/feature/2.0` (Fabric-Project/Satin) into this
fork's `feature/2.0-metal-4` branch, so we always know which upstream SHA the
Metal 4 work is currently based on.

- **Upstream remote:** `upstream` → `git@github.com:Fabric-Project/Satin.git`
- **Upstream branch:** `feature/2.0`
- **Local branch:** `feature/2.0-metal-4`

## How to sync

```sh
git fetch upstream
git log --oneline HEAD..upstream/feature/2.0   # preview incoming commits
git merge upstream/feature/2.0                  # resolve conflicts, build, commit
```

After merging, add a row below with the new upstream tip SHA, then verify with
`swift build` (and the visual tests on-device when reference PNGs change).

## Log

| Date       | Upstream tip merged | Merge commit | Notes |
|------------|---------------------|--------------|-------|
| (baseline) | `c7e959e4` "depth format test" | — | Last upstream point the Metal 4 branch was based on before tracking started. |
| 2026-05-29 | `9d3e4d53` "Remove references" | `c13e50c5` | 3 commits (normals fix, opaqueness test, remove references). Conflicts: kept ours for Metal 4 visual-reference PNGs except `compute-noise.png` (took upstream); kept ours for `GeometryCoverageTests` tolerance; took upstream for `VisualRendererTests` `makeOpaque` path and `BlendingRendererTests`. Post-merge: `testParametricGeometry` failed because upstream's normals fix changed the lit output but we kept our old `geometry-parametric.png`; regenerated that one baseline under the Metal 4 backend (`SATIN_RECORD_REFERENCE_IMAGES=1`). Full suite green (146 passed). No Metal 4 backend source conflicted. |
