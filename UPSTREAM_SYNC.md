# Upstream Sync Log

Tracks each merge of `upstream/feature/2.0` (Fabric-Project/Satin) into this
fork's `feature/2.0-metal-4` branch, so we always know which upstream SHA the
Metal 4 work is currently based on.

- **Upstream remote:** `upstream` → `git@github.com:Fabric-Project/Satin.git`
- **Upstream branch:** `main` (as of 2026-06-21 upstream consolidated `feature/2.0`
  into `main`; `feature/2.0` is fully contained in `main`. Track `main` going forward.)
- **Local branch:** `feature/2.0-metal-4`

## How to sync

```sh
git fetch upstream
git log --oneline HEAD..upstream/main   # preview incoming commits
git merge upstream/main                 # resolve conflicts, build, commit
```

After merging, add a row below with the new upstream tip SHA, then verify with
`swift build` (and the visual tests on-device when reference PNGs change).

## Log

| Date       | Upstream tip merged | Merge commit | Notes |
|------------|---------------------|--------------|-------|
| (baseline) | `c7e959e4` "depth format test" | — | Last upstream point the Metal 4 branch was based on before tracking started. |
| 2026-05-29 | `9d3e4d53` "Remove references" | `c13e50c5` | 3 commits (normals fix, opaqueness test, remove references). Conflicts: kept ours for Metal 4 visual-reference PNGs except `compute-noise.png` (took upstream); kept ours for `GeometryCoverageTests` tolerance; took upstream for `VisualRendererTests` `makeOpaque` path and `BlendingRendererTests`. Post-merge: `testParametricGeometry` failed because upstream's normals fix changed the lit output but we kept our old `geometry-parametric.png`; regenerated that one baseline under the Metal 4 backend (`SATIN_RECORD_REFERENCE_IMAGES=1`). Full suite green (146 passed). No Metal 4 backend source conflicted. |
| 2026-06-03 | `a58fb2a6` "Add parametric surface helper options" | `1240707a` | 11 commits: normals NaN-hardening (new `SafeNormalize.metal`), SSAO→XeGTAO rewrite (new prefilter/denoise materials + shaders, dropped blur stage), new `CycloramaGeometry`, expanded `ParametricGeometry`, `Protocols→Core/Objects` + `Materials→PostProcessing/Materials` file moves, AR/example fixes. Conflicts: `SsaoPostProcessEncoder.swift` — re-implemented our Metal 4 `draw(frameCommand:)` override on top of upstream's new XeGTAO pipeline (prefilter→ssao→denoise→composite) and kept upstream's `syncMaterialParameters()`; `CHANGELOG.md` — kept our Metal 4 + Architecture Refactor sections atop upstream's full changelog; `project.pbxproj` — kept our Metal 4 file refs (ours-add/theirs-empty). Build clean, full suite green (149 passed); no baseline regeneration needed. |
| 2026-06-08 | `34847674` "Update sample for 2.0" | `87f3cf13` | 14 commits, **docs/example only** — README rewrite, new `Images/` doc screenshots, and `Example` `ParametricSurfacesRenderer` updates. No `Sources/` or `Tests/` changes. Clean auto-merge, no conflicts. Build clean; tests not re-run (no library/test code changed). |
| 2026-06-21 | `63e8c79d` "Mark public variables useful to Fabric" (on **`upstream/main`**) | `bc482380` | First sync off `main` after upstream merged `feature/2.0`→`main`. 11 commits, net diff just 4 files: `Material.swift` (shadow passes no longer use the alpha-OIT depth-stencil state — new `shadow:` flag on `bindDepthStates`), `Package.swift` (**min OS bumped macOS 14→15, iOS 17→18**; visionOS v2), `ParametricGeometry.swift` (`vertexData`/`indexData` made public), `VisualRendererTests.swift` (whitespace). Clean auto-merge, 0 conflicts despite Metal 4 also touching `Material.swift`. `swift build` clean (only new `CVDisplayLink` deprecation warnings surfaced by the macOS 15 floor). Tests not re-run (no ref-image changes in net diff). |
