import { renderMainMenu } from "./main-menu.js";
import { createHud } from "./hud.js";
import { renderGameOver } from "./game-over.js";
import type { Tier } from "../state/tiers.js";
import { newCombatState, tryMove, type CombatState } from "../state/combat.js";
import { createScene } from "../game/scene.js";
import { createGrid, GRID_TILE_HIGHLIGHT_COLOR } from "../game/grid.js";
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
      onEnter: (mode, tier) => {
        if (mode === "offline") {
          startGame(tier, null);
        }
      },
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

  const startGame = (tier: Tier, onlineRun: OnlineRun | null): void => {
    teardown?.();
    root.innerHTML = "";
    root.className = "screen game";

    const isOnline = onlineRun !== null;
    state = newCombatState(tier, isOnline);

    const canvas = document.createElement("canvas");
    canvas.className = "game-canvas";
    root.appendChild(canvas);

    const sceneBundle = createScene(canvas);
    const grid = createGrid(sceneBundle.scene);
    const actorMeshes = createActorMeshes(sceneBundle.scene, state);
    syncActorMeshes(actorMeshes, state);

    const hud = createHud(root, state);

    const detachInput = attachGridInput(canvas, sceneBundle, grid, ({ x, y }) => {
      if (!state) return;
      const result = tryMove(state, x, y);
      if (!result.ok) {
        grid.highlight([{ x, y }], 0x7a1f1f);
        window.setTimeout(() => grid.clearHighlight(), 200);
        return;
      }
      syncActorMeshes(actorMeshes, state);
      hud.refresh(state);
      if (onlineRun) {
        onlineRun.pendingActions.push(...packMove(x, y));
      }
      if (state.run.gameOver) {
        renderGameOver(root, state, toMenu);
      }
    });

    hud.onExit(toMenu);
    hud.onReset(() => {
      if (!state) return;
      state = newCombatState(state.run.tier, state.online);
      syncActorMeshes(actorMeshes, state);
      hud.refresh(state);
      if (onlineRun) {
        onlineRun.pendingActions = [];
      }
    });
    hud.onConfirm(async () => {
      if (!state) return;
      grid.highlight([{ x: state.player.x, y: state.player.y }], GRID_TILE_HIGHLIGHT_COLOR);
      window.setTimeout(() => grid.clearHighlight(), 250);

      if (!onlineRun) return;
      if (onlineRun.submitting) return;
      if (onlineRun.pendingActions.length === 0) return;

      onlineRun.submitting = true;
      const batch = onlineRun.pendingActions;
      onlineRun.pendingActions = [];
      try {
        await onlineRun.client.confirmTurn(onlineRun.gameId, batch);
      } catch (err) {
        // TX reverted — restore the pending batch so user can see what failed.
        onlineRun.pendingActions = batch;
        // eslint-disable-next-line no-console
        console.error("[descent] confirm_turn failed", err);
      } finally {
        onlineRun.submitting = false;
      }
    });
    hud.onAbility(() => {
      // Ability targeting not wired yet — abilities are defined in state but
      // click-to-target UX + packAbility calldata lands in the next pass.
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
      sceneBundle.dispose();
      hud.root.remove();
      canvas.remove();
    };
  };

  toMenu();
}
