import type { CombatState } from "../state/combat.js";
import type { RunMeta } from "../state/run-meta.js";

interface GameOverOptions {
  loadSettlement?: () => Promise<RunMeta | null>;
}

export function renderGameOver(
  container: HTMLElement,
  state: CombatState,
  onReturn: () => void,
  options: GameOverOptions = {},
): void {
  const overlay = document.createElement("div");
  overlay.className = "game-over";

  const card = document.createElement("div");
  card.className = "game-over-card";

  const title = document.createElement("h2");
  // HP ≤ 0 is the only game-over path — stamina refills each turn.
  title.textContent = "YOU DIED";
  card.appendChild(title);

  const stats = document.createElement("p");
  stats.textContent = `${state.run.tier.name} run · score ${state.run.score} · ${state.run.roomsCleared} rooms cleared`;
  card.appendChild(stats);

  const settlement = document.createElement("p");
  settlement.className = "game-over-settlement";
  settlement.textContent = settlementMessage(null);
  card.appendChild(settlement);

  const clearPolling = startSettlementPolling(options.loadSettlement, settlement);

  const btn = document.createElement("button");
  btn.textContent = "Back to menu";
  btn.addEventListener("click", () => {
    clearPolling();
    overlay.remove();
    onReturn();
  });
  card.appendChild(btn);

  overlay.appendChild(card);
  container.appendChild(overlay);
}

function startSettlementPolling(
  loadSettlement: GameOverOptions["loadSettlement"],
  settlementLabel: HTMLElement,
): () => void {
  if (!loadSettlement) return () => {};
  let cancelled = false;

  const refresh = async (): Promise<void> => {
    try {
      const settlement = await loadSettlement();
      if (cancelled) return;
      settlementLabel.textContent = settlementMessage(settlement);
    } catch {
      if (cancelled) return;
      settlementLabel.textContent =
        "Run ended on Katana. Waiting for oracle settlement on mainnet; retrying settlement check...";
    }
  };

  void refresh();
  const timer = window.setInterval(() => {
    void refresh();
  }, 3000);

  return () => {
    cancelled = true;
    window.clearInterval(timer);
  };
}

function settlementMessage(settlement: RunMeta | null): string {
  if (!settlement || settlement.status === "ended_pending_oracle") {
    return "Run ended on Katana. Waiting for oracle settlement on mainnet for official final score and rewards.";
  }

  if (settlement.status === "active") {
    return "Run still marked active in settlement registry. If this persists, refresh the menu and resume once.";
  }

  const scoreText =
    typeof settlement.finalScore === "number" ? ` Official score: ${settlement.finalScore}.` : "";
  const rewardText =
    settlement.reward !== undefined ? ` Reward: ${settlement.reward.toString()}.` : "";

  if (settlement.status === "claimed") {
    return `Settlement complete and rewards claimed.${scoreText}${rewardText}`;
  }

  return `Settlement complete.${scoreText}${rewardText}`;
}
