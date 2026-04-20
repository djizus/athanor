import { TIER_STANDARD, tierFeeRaw, type Tier } from "../state/tiers.js";
import type { DojoClient, RunSummary } from "../dojo/client.js";

export interface MainMenuContext {
  /**
   * Null when the client is not configured (env vars missing). The menu shows
   * a helpful message in that case and the "Start Run" button stays disabled
   * until `scripts/deploy_slot.sh` has populated `client/.env.slot`.
   */
  dojo: DojoClient | null;
  /** Approves the entry fee and submits `spawn(gameId, settings_id)` on-chain. */
  onOnlineSpawn: (tier: Tier) => Promise<void>;
  onResumeRun: (run: RunSummary) => Promise<void>;
}

const MINT_AMOUNT = 100_000n;

export function renderMainMenu(container: HTMLElement, ctx: MainMenuContext): void {
  container.innerHTML = "";
  container.className = "screen main-menu";

  const card = document.createElement("div");
  card.className = "menu-card";

  const title = document.createElement("h1");
  title.textContent = "ATHANOR: ASCEND";
  card.appendChild(title);

  const subtitle = document.createElement("p");
  subtitle.className = "subtitle";
  subtitle.textContent =
    "Endless tactical roguelike. 80 HP, 80 stamina/turn — refilled. Every move counts.";
  card.appendChild(subtitle);

  card.appendChild(buildOnlineColumn(ctx));

  const note = document.createElement("p");
  note.className = "note";
  note.textContent = ctx.dojo
    ? "Dev burner connected. mLORDS mint is unrestricted for testing."
    : "Dev env not bootstrapped — run scripts/deploy_slot.sh.";
  card.appendChild(note);

  container.appendChild(card);
}

function buildOnlineColumn(ctx: MainMenuContext): HTMLElement {
  const col = document.createElement("div");
  col.className = "tier-column";

  const heading = document.createElement("h2");
  heading.textContent = "Start Run";
  col.appendChild(heading);

  const balanceLabel = document.createElement("p");
  balanceLabel.className = "column-note balance-label";
  balanceLabel.textContent = ctx.dojo ? "Loading balance..." : "Dev env not bootstrapped";
  col.appendChild(balanceLabel);

  const mintBtn = document.createElement("button");
  mintBtn.className = "tier-button mint-button";
  mintBtn.textContent = `Mint ${MINT_AMOUNT.toLocaleString()} mLORDS`;
  mintBtn.disabled = !ctx.dojo;
  col.appendChild(mintBtn);

  const startBtn = document.createElement("button");
  startBtn.className = "tier-button tier-standard";
  const fee = TIER_STANDARD.entryFeeLords.toLocaleString();
  startBtn.textContent = `Start — ${TIER_STANDARD.heroHp} HP · ${TIER_STANDARD.staminaPerTurn} STA/turn · ${fee} mLORDS`;
  startBtn.disabled = !ctx.dojo;
  col.appendChild(startBtn);

  const resumeBtn = document.createElement("button");
  resumeBtn.className = "tier-button tier-standard";
  resumeBtn.textContent = "Resume latest run";
  resumeBtn.disabled = true;
  col.appendChild(resumeBtn);

  if (!ctx.dojo) {
    return col;
  }

  const dojo = ctx.dojo;
  let currentBalance = 0n;
  let busy = false;
  let latestActiveRun: RunSummary | null = null;

  const setBusy = (on: boolean): void => {
    busy = on;
    mintBtn.disabled = on;
    startBtn.disabled = on;
    resumeBtn.disabled = on || latestActiveRun === null;
    refreshAffordability();
  };

  const refreshAffordability = (): void => {
    balanceLabel.textContent = `Balance: ${currentBalance.toLocaleString()} mLORDS`;
    const affordable = currentBalance >= TIER_STANDARD.entryFeeLords;
    startBtn.disabled = busy || !affordable;
    resumeBtn.disabled = busy || latestActiveRun === null;
    startBtn.title = affordable
      ? ""
      : `Need ${TIER_STANDARD.entryFeeLords} mLORDS — mint more`;
  };

  const reloadRuns = async (): Promise<void> => {
    try {
      const runs = await dojo.listRuns();
      latestActiveRun = runs.find((run) => run.endedAt === 0n) ?? null;
      if (latestActiveRun) {
        resumeBtn.textContent = `Resume run #${latestActiveRun.gameId} · Room ${latestActiveRun.roomId + 1}`;
      } else {
        resumeBtn.textContent = "No active run to resume";
      }
    } catch (err) {
      resumeBtn.textContent = `Resume unavailable: ${(err as Error).message}`;
      latestActiveRun = null;
    }
    refreshAffordability();
  };

  const reloadBalance = async (): Promise<void> => {
    try {
      const b = await dojo.lordsBalance();
      currentBalance = b.wholeTokens;
    } catch (err) {
      balanceLabel.textContent = `Balance read failed: ${(err as Error).message}`;
      return;
    }
    refreshAffordability();
  };

  mintBtn.addEventListener("click", async () => {
    if (busy) return;
    setBusy(true);
    mintBtn.textContent = "Minting...";
    try {
      await dojo.mintLords(MINT_AMOUNT);
      await reloadBalance();
    } catch (err) {
      balanceLabel.textContent = `Mint failed: ${(err as Error).message}`;
    } finally {
      mintBtn.textContent = `Mint ${MINT_AMOUNT.toLocaleString()} mLORDS`;
      setBusy(false);
    }
  });

  startBtn.addEventListener("click", async () => {
    if (busy) return;
    setBusy(true);
    const originalLabel = startBtn.textContent ?? "";
    startBtn.textContent = "Paying fee...";
    try {
      await dojo.approveLords(tierFeeRaw(TIER_STANDARD));
      startBtn.textContent = "Spawning...";
      await ctx.onOnlineSpawn(TIER_STANDARD);
    } catch (err) {
      balanceLabel.textContent = `Spawn failed: ${(err as Error).message}`;
      startBtn.textContent = originalLabel;
      setBusy(false);
    }
  });

  resumeBtn.addEventListener("click", async () => {
    if (busy || !latestActiveRun) return;
    setBusy(true);
    const originalLabel = resumeBtn.textContent ?? "Resume latest run";
    resumeBtn.textContent = "Resuming...";
    try {
      await ctx.onResumeRun(latestActiveRun);
    } catch (err) {
      balanceLabel.textContent = `Resume failed: ${(err as Error).message}`;
      resumeBtn.textContent = originalLabel;
      setBusy(false);
    }
  });

  void reloadBalance();
  void reloadRuns();

  return col;
}
