import { renderMainMenu } from "./main-menu.js";
import { createHud } from "./hud.js";
import { renderGameOver } from "./game-over.js";
import { TIER_STANDARD, type Tier } from "../state/tiers.js";
import {
  canUseAbility,
  computeReachable,
  newCombatState,
  tryMove,
  tryUseAbility,
  type CombatState,
  type Position,
} from "../state/combat.js";
import { createScene } from "../game/scene.js";
import { createGrid, TILE_FLASH_BAD_COLOR, TILE_FLASH_HIT_COLOR } from "../game/grid.js";
import { createObstacles } from "../game/obstacles.js";
import { createOrbs } from "../game/orbs.js";
import { createActorMeshes, syncActorMeshes } from "../game/actor.js";
import { attachGridInput } from "../game/input.js";
import { createDojoClient, packAbility, packMove, type DojoClient } from "../dojo/client.js";
import { createSigner } from "../dojo/burner.js";
import { isConfigured, loadDojoConfig } from "../dojo/config.js";
import type { AbilityId } from "../state/constants.js";
import { abilityPrompt, buildAbilityPayload, getValidAbilityTargets } from "../state/targeting.js";

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

  const toMenu = (): void => {
    teardown?.();
    teardown = null;
    state = null;
    online = null;

    renderMainMenu(root, {
      dojo,
      onOnlineSpawn: async (tier) => {
        if (!dojo) throw new Error("Online not configured");
        const gameId = await dojo.nextGameId();
        await dojo.spawn(gameId, tier.settingsId);
        await dojo.enterRoom(gameId, 0);
        const liveState = await dojo.loadRun(gameId, tier);
        if (!liveState) throw new Error(`Run ${gameId} not found after spawn`);
        online = { client: dojo, gameId, pendingActions: [], submitting: false };
        startGame(tier, online, liveState);
      },
      onResumeRun: async (run) => {
        if (!dojo) throw new Error("Online not configured");
        const liveState = await dojo.loadRun(run.gameId, TIER_STANDARD);
        if (!liveState) throw new Error(`Run ${run.gameId} not found`);
        online = { client: dojo, gameId: run.gameId, pendingActions: [], submitting: false };
        startGame(TIER_STANDARD, online, liveState);
      },
    });
  };

  const startGame = (tier: Tier, onlineRun: OnlineRun, initialState: CombatState): void => {
    teardown?.();
    root.innerHTML = "";
    root.className = "screen game";

    const combat = initialState;
    state = combat;

    const canvas = document.createElement("canvas");
    canvas.className = "game-canvas";
    root.appendChild(canvas);

    const sceneBundle = createScene(canvas);
    const grid = createGrid(sceneBundle.scene);
    const obstacles = createObstacles(sceneBundle.scene, combat.obstacles);
    const orbs = createOrbs(sceneBundle.scene, combat);
    const actorMeshes = createActorMeshes(sceneBundle.scene, combat);

    const hud = createHud(root, combat);
    let selectedAbilityId: AbilityId | null = null;

    const syncFromChain = async (minTurnIndex: number = 0): Promise<void> => {
      let latest: CombatState | null = null;
      for (let attempt = 0; attempt < 12; attempt++) {
        latest = await onlineRun.client.loadRun(onlineRun.gameId, tier);
        if (latest && latest.run.turnIndex >= minTurnIndex) {
          break;
        }
        await new Promise((resolve) => window.setTimeout(resolve, 350));
      }

      if (!latest || latest.run.turnIndex < minTurnIndex) {
        throw new Error(`Run ${onlineRun.gameId} could not be refreshed from Torii`);
      }
      state = latest;
      selectedAbilityId = null;
      syncActorMeshes(actorMeshes, state);
      orbs.sync(state);
      refreshPresentation();
      if (state.run.gameOver) {
        renderGameOver(root, state, toMenu);
      }
    };

    const refreshPresentation = (): void => {
      if (!state) return;
      const abilityRange = selectedAbilityId === null ? [] : getValidAbilityTargets(state, selectedAbilityId);
      grid.setMoveRange(selectedAbilityId === null ? computeReachable(state) : []);
      grid.setAbilityRange(abilityRange);
      grid.setDanger(collectIntentTiles(state));
      grid.setSelected(selectedAbilityId === null ? [] : [{ x: state.player.x, y: state.player.y }]);
      hud.refresh(state, {
        selectedAbilityId,
        statusText: abilityPrompt(selectedAbilityId),
        submitting: onlineRun.submitting,
      });
    };

    const clearAbilitySelection = (): void => {
      selectedAbilityId = null;
      refreshPresentation();
    };

    const toggleAbilitySelection = (abilityId: AbilityId): void => {
      if (!state) return;
      if (!canUseAbility(state, abilityId)) {
        return;
      }
      if (selectedAbilityId === abilityId) {
        clearAbilitySelection();
        return;
      }
      selectedAbilityId = abilityId;
      refreshPresentation();
    };

    refreshPresentation();

    const detachInput = attachGridInput(canvas, sceneBundle, grid, ({ x, y }) => {
      if (!state) return;
      if (onlineRun.submitting) return;
      if (selectedAbilityId !== null) {
        const target = { x, y };
        const payload = buildAbilityPayload(state, selectedAbilityId, target);
        const result = payload ? tryUseAbility(state, selectedAbilityId, x, y) : { ok: false };
        if (!payload || !result.ok) {
          grid.flash([{ x, y }], TILE_FLASH_BAD_COLOR, 200);
          return;
        }

        onlineRun.pendingActions.push(
          ...packAbility(selectedAbilityId, payload.targetMode, payload.targetA, payload.targetB),
        );
        clearAbilitySelection();
        syncActorMeshes(actorMeshes, state);
        orbs.sync(state);
        refreshPresentation();
        grid.flash(result.affectedTiles ?? [{ x, y }], TILE_FLASH_HIT_COLOR, 180);
        if (state.run.gameOver) {
          renderGameOver(root, state, toMenu);
        }
        return;
      }

      const result = tryMove(state, x, y);
      if (!result.ok) {
        grid.flash([{ x, y }], TILE_FLASH_BAD_COLOR, 200);
        return;
      }
      syncActorMeshes(actorMeshes, state);
      orbs.sync(state);
      refreshPresentation();
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
      selectedAbilityId = null;
      syncActorMeshes(actorMeshes, state);
      orbs.sync(state);
      refreshPresentation();
      onlineRun.pendingActions = [];
    });
    hud.onConfirm(async () => {
      if (!state) return;
      if (onlineRun.submitting) return;
      // Confirm visual: briefly flash the player's tile. The real turn end
      // (enemy phase, telegraph resolves, stamina refill) is driven by the
      // contract's confirm_turn — the client applies state from Torii.
      grid.flash([{ x: state.player.x, y: state.player.y }], TILE_FLASH_HIT_COLOR, 250);

      if (onlineRun.submitting) return;

      onlineRun.submitting = true;
      refreshPresentation();
      const expectedTurnIndex = state.run.turnIndex + 1;
      const batch = onlineRun.pendingActions;
      onlineRun.pendingActions = [];
      try {
        await onlineRun.client.confirmTurn(onlineRun.gameId, batch);
        await syncFromChain(expectedTurnIndex);
      } catch (err) {
        onlineRun.pendingActions = batch;
        // eslint-disable-next-line no-console
        console.error("[ascend] confirm_turn failed", err);
      } finally {
        onlineRun.submitting = false;
        refreshPresentation();
      }
    });
    hud.onAbility((abilityId) => {
      toggleAbilitySelection(abilityId);
    });

    const onKeyDown = (ev: KeyboardEvent): void => {
      if (!state) return;
      if (onlineRun.submitting) return;
      if (ev.key === "Escape") {
        clearAbilitySelection();
        return;
      }

      const index = Number(ev.key) - 1;
      if (index >= 0 && index <= 4) {
        toggleAbilitySelection(index as AbilityId);
      }
    };
    window.addEventListener("keydown", onKeyDown);

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
      window.removeEventListener("keydown", onKeyDown);
      obstacles.dispose();
      orbs.dispose();
      sceneBundle.dispose();
      hud.root.remove();
      canvas.remove();
    };
  };

  toMenu();
}
