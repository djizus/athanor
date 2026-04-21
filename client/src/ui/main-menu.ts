import { TIER_STANDARD, tierFeeRaw, type Tier } from "../state/tiers.js";
import type { DojoClient } from "../dojo/client.js";
import type { RunMeta } from "../state/run-meta.js";

export interface MainMenuContext {
  /**
   * Null when the client is not configured (env vars missing). The menu shows
   * a helpful message in that case and the "Start Run" button stays disabled
   * until `scripts/deploy_slot.sh` has populated `client/.env.slot`.
   */
  dojo: DojoClient | null;
  /** Approves the entry fee and submits `spawn(gameId, settings_id)` on-chain. */
  onOnlineSpawn: (tier: Tier) => Promise<void>;
  onResumeRun: (run: RunMeta) => Promise<void>;
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

  card.appendChild(buildRunHub(ctx));

  const note = document.createElement("p");
  note.className = "note";
  note.textContent = ctx.dojo
    ? "Dev burner connected. mLORDS mint is unrestricted for testing."
    : "Dev env not bootstrapped — run scripts/deploy_slot.sh.";
  card.appendChild(note);

  container.appendChild(card);
}

function buildRunHub(ctx: MainMenuContext): HTMLElement {
  const col = document.createElement("div");
  col.className = "run-hub";

  const heading = document.createElement("h2");
  heading.textContent = "Mainnet Run Hub";
  col.appendChild(heading);

  const buySection = document.createElement("div");
  buySection.className = "menu-section";
  const buyTitle = document.createElement("h3");
  buyTitle.textContent = "Buy Run";
  buySection.appendChild(buyTitle);

  const balanceLabel = document.createElement("p");
  balanceLabel.className = "column-note balance-label";
  balanceLabel.textContent = ctx.dojo ? "Loading balance..." : "Dev env not bootstrapped";
  buySection.appendChild(balanceLabel);

  const mintBtn = document.createElement("button");
  mintBtn.className = "tier-button mint-button";
  mintBtn.textContent = `Mint ${MINT_AMOUNT.toLocaleString()} mLORDS`;
  mintBtn.disabled = !ctx.dojo;
  buySection.appendChild(mintBtn);

  const startBtn = document.createElement("button");
  startBtn.className = "tier-button tier-standard";
  const fee = TIER_STANDARD.entryFeeLords.toLocaleString();
  startBtn.textContent = `Start — ${TIER_STANDARD.heroHp} HP · ${TIER_STANDARD.staminaPerTurn} STA/turn · ${fee} mLORDS`;
  startBtn.disabled = !ctx.dojo;
  buySection.appendChild(startBtn);
  col.appendChild(buySection);

  const activeSection = document.createElement("div");
  activeSection.className = "menu-section";
  const activeTitle = document.createElement("h3");
  activeTitle.textContent = "Resume Active Run";
  activeSection.appendChild(activeTitle);

  const resumeBtn = document.createElement("button");
  resumeBtn.className = "tier-button tier-standard";
  resumeBtn.textContent = "Resume latest run";
  resumeBtn.disabled = true;
  activeSection.appendChild(resumeBtn);
  col.appendChild(activeSection);

  const pendingSection = document.createElement("div");
  pendingSection.className = "menu-section";
  const pendingTitle = document.createElement("h3");
  pendingTitle.textContent = "Pending Settlement";
  pendingSection.appendChild(pendingTitle);
  const pendingList = document.createElement("ul");
  pendingList.className = "run-list";
  pendingSection.appendChild(pendingList);
  col.appendChild(pendingSection);

  const settledSection = document.createElement("div");
  settledSection.className = "menu-section";
  const settledTitle = document.createElement("h3");
  settledTitle.textContent = "Recent Settled Runs";
  settledSection.appendChild(settledTitle);
  const settledList = document.createElement("ul");
  settledList.className = "run-list";
  settledSection.appendChild(settledList);
  col.appendChild(settledSection);

  if (!ctx.dojo) {
    pendingList.innerHTML = "<li>Mainnet registry unavailable</li>";
    settledList.innerHTML = "<li>Mainnet registry unavailable</li>";
    return col;
  }

  const dojo = ctx.dojo;
  let currentBalance = 0n;
  let busy = false;
  let latestActiveRun: RunMeta | null = null;

  const renderRunList = (target: HTMLElement, runs: RunMeta[], emptyText: string): void => {
    target.innerHTML = "";
    if (runs.length === 0) {
      const li = document.createElement("li");
      li.textContent = emptyText;
      target.appendChild(li);
      return;
    }
    for (const run of runs.slice(0, 4)) {
      const li = document.createElement("li");
      const parts = [`#${run.tokenId}`, run.status.replaceAll("_", " ")];
      if (typeof run.finalScore === "number") {
        parts.push(`score ${run.finalScore}`);
      }
      if (typeof run.roomId === "number") {
        parts.push(`room ${run.roomId + 1}`);
      }
      li.textContent = parts.join(" · ");
      target.appendChild(li);
    }
  };

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
      const address = dojo.address;
      const [activeRuns, pendingRuns, settledRuns] = await Promise.all([
        dojo.runRegistry.listActiveRuns(address),
        dojo.runRegistry.listPendingSettlements(address),
        dojo.runRegistry.listSettledRuns(address),
      ]);

      latestActiveRun = activeRuns[0] ?? null;
      if (latestActiveRun) {
        const roomLabel =
          typeof latestActiveRun.roomId === "number" ? ` · Room ${latestActiveRun.roomId + 1}` : "";
        resumeBtn.textContent = `Resume run #${latestActiveRun.tokenId}${roomLabel}`;
      } else {
        resumeBtn.textContent = "No active run to resume";
      }

      renderRunList(pendingList, pendingRuns, "No ended runs awaiting oracle");
      renderRunList(settledList, settledRuns, "No settled runs yet");
    } catch (err) {
      resumeBtn.textContent = `Resume unavailable: ${(err as Error).message}`;
      latestActiveRun = null;
      renderRunList(pendingList, [], "Settlement status unavailable");
      renderRunList(settledList, [], "Settlement status unavailable");
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
