import { renderMainMenu } from "./main-menu.js";
import { createHud } from "./hud.js";
import { renderGameOver } from "./game-over.js";
import type { Tier } from "../state/tiers.js";
import {
  computeEnemyIntents,
  computeReachable,
  newCombatState,
  refillStamina,
  tryMove,
  type CombatState,
  type Position,
} from "../state/combat.js";
import { createScene } from "../game/scene.js";
import { createGrid, TILE_FLASH_BAD_COLOR, TILE_FLASH_HIT_COLOR } from "../game/grid.js";
import { createObstacles } from "../game/obstacles.js";
import { createActorMeshes, syncActorMeshes } from "../game/actor.js";
import { attachGridInput } from "../game/input.js";
import { createDojoClient, packMove, type DojoClient } from "../dojo/client.js";
import { createSigner } from "../dojo/burner.js";
import { isConfigured, loadDojoConfig } from "../dojo/config.js";

type Teardown = () => void;

interface OnlineRun {
  client: DojoClient;
  gameId: number;
  pendingActions: number[];
  submitting: boolean;
}

function collectIntentTiles(state: CombatState): Position[] {
  const out: Position[] = [];
  for (const enemy of state.enemies) {
    if (!enemy.alive || !enemy.intent) continue;
    out.push(...enemy.intent.tiles);
  }
  return out;
}

export function mountApp(root: HTMLElement): void {
  root.innerHTML = "";

  const cfg = loadDojoConfig();
  const dojo: DojoClient | null = isConfigured(cfg)
    ? createDojoClient(cfg, createSigner(cfg))
    : null;

  let teardown: Teardown | null = null;
  let state: CombatState | null = null;
  let online: OnlineRun | null = null;
  let nextGameId = 1;

  const toMenu = (): void => {
    teardown?.();
    teardown = null;
    state = null;
    online = null;

    renderMainMenu(root, {
      dojo,
      onOnlineSpawn: async (tier) => {
        if (!dojo) throw new Error("Online not configured");
        const gameId = nextGameId++;
        await dojo.spawn(gameId, tier.settingsId);
        await dojo.enterRoom(gameId, 0);
        online = { client: dojo, gameId, pendingActions: [], submitting: false };
        startGame(tier, online);
      },
    });
  };

  const startGame = (tier: Tier, onlineRun: OnlineRun): void => {
    teardown?.();
    root.innerHTML = "";
    root.className = "screen game";

    const combat = newCombatState(tier);
    state = combat;

    const canvas = document.createElement("canvas");
    canvas.className = "game-canvas";
    root.appendChild(canvas);

    const sceneBundle = createScene(canvas);
    const grid = createGrid(sceneBundle.scene);
    const obstacles = createObstacles(sceneBundle.scene, combat.obstacles);
    const actorMeshes = createActorMeshes(sceneBundle.scene, combat);

    const hud = createHud(root, combat);

    const refreshOverlays = (): void => {
      if (!state) return;
      grid.setReachable(computeReachable(state));
      grid.setDanger(collectIntentTiles(state));
    };
    refreshOverlays();

    const detachInput = attachGridInput(canvas, sceneBundle, grid, ({ x, y }) => {
      if (!state) return;
      const result = tryMove(state, x, y);
      if (!result.ok) {
        grid.flash([{ x, y }], TILE_FLASH_BAD_COLOR, 200);
        return;
      }
      syncActorMeshes(actorMeshes, state);
      hud.refresh(state);
      refreshOverlays();
      grid.flash([{ x: state.player.x, y: state.player.y }], TILE_FLASH_HIT_COLOR, 150);
      onlineRun.pendingActions.push(...packMove(x, y));
      if (state.run.gameOver) {
        renderGameOver(root, state, toMenu);
      }
    });

    hud.onExit(toMenu);
    hud.onReset(() => {
      if (!state) return;
      const tierRef = state.run.tier;
      state = newCombatState(tierRef);
      syncActorMeshes(actorMeshes, state);
      hud.refresh(state);
      refreshOverlays();
      onlineRun.pendingActions = [];
    });
    hud.onConfirm(async () => {
      if (!state) return;
      // Confirm visual: briefly flash the player's tile. The real turn end
      // (enemy phase, telegraph resolves, stamina refill) is driven by the
      // contract's confirm_turn — the client applies state from Torii.
      grid.flash([{ x: state.player.x, y: state.player.y }], TILE_FLASH_HIT_COLOR, 250);

      if (onlineRun.submitting) return;
      if (onlineRun.pendingActions.length === 0) {
        // Empty-turn confirm: act like a no-op locally so intents rotate and
        // stamina refills. Once Torii subscription replaces the placeholder
        // combat state this branch goes away.
        computeEnemyIntents(state);
        refillStamina(state);
        hud.refresh(state);
        refreshOverlays();
        return;
      }

      onlineRun.submitting = true;
      const batch = onlineRun.pendingActions;
      onlineRun.pendingActions = [];
      try {
        await onlineRun.client.confirmTurn(onlineRun.gameId, batch);
        // TODO(torii): replace this optimistic shim with a Torii subscription
        // that mirrors the contract's post-enemy-phase state. For now the
        // contract has already refilled stamina on-chain; we mirror locally
        // so the HUD isn't stale until the next re-sync lands.
        if (state) {
          refillStamina(state);
          computeEnemyIntents(state);
          hud.refresh(state);
          refreshOverlays();
        }
      } catch (err) {
        onlineRun.pendingActions = batch;
        // eslint-disable-next-line no-console
        console.error("[ascend] confirm_turn failed", err);
      } finally {
        onlineRun.submitting = false;
      }
    });
    hud.onAbility(() => {
      // Ability targeting not wired yet.
    });

    const clock = { running: true };
    const frame = (): void => {
      if (!clock.running) return;
      sceneBundle.renderer.render(sceneBundle.scene, sceneBundle.camera);
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);

    teardown = () => {
      clock.running = false;
      detachInput();
      obstacles.dispose();
      sceneBundle.dispose();
      hud.root.remove();
      canvas.remove();
    };
  };

  toMenu();
}
