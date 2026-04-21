# Athanor 3D Asset Generation

Generate 3D GLB assets for Athanor:Ascend via the Meshy AI API.

Pipeline: text prompt -> Meshy `text-to-3d` preview (lowpoly) -> refine (PBR,
auto-size, origin-at-bottom) -> download GLB -> postprocess
(weld/dedup/prune/textureCompress 1024) -> save to `client/public/models/` with
a metadata sidecar.

## Quick Start

```bash
# Requires MESHY_KEY in repo-root .env
# (get one at https://www.meshy.ai/api)

pnpm -C scripts/generate-assets install   # or: npm install, yarn install

# Dry run (print plan, no API calls)
pnpm -C scripts/generate-assets generate:dry

# Generate all 8 MVP assets (tiles, obstacles, characters)
pnpm -C scripts/generate-assets generate

# Single asset
pnpm -C scripts/generate-assets generate -- --only hero

# Single category
pnpm -C scripts/generate-assets generate -- --category tiles

# Fast iteration: geometry-only (no refine/texturing)
pnpm -C scripts/generate-assets generate -- --preview-only

# Overwrite existing files
pnpm -C scripts/generate-assets generate -- --force --only hero
```

## Folder Structure

```
scripts/generate-assets/
├── data/
│   ├── style.json            # shared prompt suffix (art direction)
│   ├── tiles.json            # tile-grass-a, tile-grass-b
│   ├── obstacles.json        # obstacle-rock, obstacle-crystal
│   └── characters.json       # hero, enemy-brute, enemy-caster, enemy-heavy
├── lib/
│   ├── env.ts                # .env loader, rate limit, retry/backoff, paths
│   ├── types.ts              # AssetJob3D, CliOptions, MeshyTaskResponse, ...
│   ├── prompts.ts            # prompt builders (append style suffix)
│   ├── meshy-client.ts       # preview -> poll -> refine -> poll -> download
│   └── postprocess.ts        # gltf-transform (weld/dedup/prune/resize)
├── generate-models.ts        # CLI entry point
├── package.json
├── tsconfig.json
└── README.md
```

## CLI Flags

| Flag | Description |
|------|-------------|
| `--category <cat>` | `tiles \| obstacles \| characters` (default: all) |
| `--only <ids>` | Comma-separated asset IDs (e.g. `hero,enemy-brute`) |
| `--preview-only` | Skip the refine stage; geometry only (cheaper, faster) |
| `--no-postprocess` | Skip weld/dedup/prune/textureCompress |
| `--force` | Overwrite existing GLBs (default: skip if already generated) |
| `--dry-run` | Print plan, no API calls |
| `--help` | Show usage |

## Meshy Settings Used

Preview:
- `model_type: "lowpoly"` — cleaner polygons, fewer faces
- `target_polycount` from the asset def (tiles 8k, obstacles 6k, hero 12k, heavy 15k)
- `symmetry_mode: "auto"`
- `auto_size: true`, `origin_at: "bottom"` — meters-scale + feet-on-floor pivot
- `pose_mode: "a-pose"` for characters
- `target_formats: ["glb"]`

Refine (default; skip with `--preview-only`):
- `enable_pbr: true` — metallic / roughness / normal / emission maps
- `remove_lighting: true` — cleans baked highlights for custom lighting
- `target_formats: ["glb"]`

## Prompt Style

All prompts receive `data/style.json:suffix` appended:

> low-poly stylized, painterly hand-painted textures, warm rim light, Bastion
> and Hades art direction, PBR baked, clean silhouette, origin at base,
> facing +Z, game-ready

## Output Paths

```
client/public/models/
├── tiles/
│   ├── tile-grass-a.glb
│   ├── tile-grass-a.thumb.png
│   └── tile-grass-a.json        # metadata sidecar
├── obstacles/
├── characters/
└── .cache/
    ├── <category>/<id>.raw.glb  # pre-postprocess GLB
    └── task-log.jsonl           # append-only event log
```

## Metadata Sidecar Shape

```json
{
  "id": "hero",
  "category": "characters",
  "prompt": "...",
  "polycount_target": 12000,
  "pose": "a-pose",
  "provider": "meshy",
  "preview_task_id": "018a...",
  "refine_task_id": "018b...",
  "generated_at": "2026-04-21T12:34:56.789Z",
  "glb_bytes": 842311,
  "thumb_path": "hero.thumb.png",
  "postprocessed": true
}
```

## Rate Limiting & Retries

- `CONCURRENCY = 2` parallel tasks (p-limit; internal fallback if not installed)
- `REQUEST_DELAY_MS = 3000` between consecutive API calls (global)
- Retry backoff on 408/409/425/429/5xx: 15s -> 30s -> 60s -> 120s
- Polling: 5s interval, 15 min max per task

## Cost & Wall-Clock (MVP)

8 assets × (preview + refine) at concurrency 2:
- Preview ~60-90s each, refine ~120-240s each
- End-to-end ~15-25 min
- ~100-150 Meshy credits total (~$4-6 depending on plan tier)

## Known Quirks

- Meshy preview GLBs are untextured; refine adds PBR maps. `--preview-only` is
  great for iterating on silhouette without burning refine credits.
- `auto_size: true` uses AI vision to estimate real-world size. Combined with
  `origin_at: "bottom"` we always get feet-on-floor pivots — no manual
  re-origin needed in the Three.js client.
- `textureCompress` uses `sharp` as encoder. If `sharp` fails to load on your
  platform, pass `--no-postprocess` and the raw GLB will be saved.
- Existing files are skipped by default. Use `--force` to regenerate.
- Re-running after a refine failure still re-creates the preview (no free
  retexture yet). Future follow-up: cache preview_task_id by asset id and
  skip straight to refine.

## Follow-ups (post-MVP)

- Full 7-enemy roster (add flanker / puller / drainer / marksman to
  `characters.json`).
- Orb GLBs (`data/orbs.json`).
- Retexture pipeline using Meshy's `retexture` endpoint to iterate on
  materials without regenerating geometry.
- Optional Draco compression (adds `DRACOLoader` to the Three.js client).

### Mixamo rigging + animations (free)

Mixamo gives free auto-rigging + ~2500 animations for humanoid bipeds. It
pairs cleanly with our Meshy A-pose characters but has no public API — it
is a manual one-shot-per-character step.

Planned workflow:

1. Request FBX output from Meshy for characters (`--format fbx`, to be added
   to the CLI). FBX is required because Mixamo does not accept GLB.
2. Upload `<id>.fbx` to https://www.mixamo.com, auto-rig (humanoid), pick
   idle / attack / hit / death animations, download each as FBX with skin.
3. (Future) Add `scripts/generate-assets/mixamo-to-glb.ts` to merge the
   animation FBX files into a single GLB via FBX2glTF + gltf-transform.
4. `actor.ts` plays the animations with `AnimationMixer`.

Caveats:

- Mixamo auto-rigger is biped-only. Heavy (stone golem, wide stance) and
  other non-humanoid enemies may need hand-rigging or stay static.
- Mesh should be a single body in T-pose or A-pose, ~2k-30k tris. Our
  Meshy lowpoly + `auto_size + origin_at: bottom + pose_mode: a-pose`
  output is already aligned with this.
- Retargeting the Mixamo skeleton to a shared rig across enemies is
  optional; for the MVP each enemy carries its own animations.
