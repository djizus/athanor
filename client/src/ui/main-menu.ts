import { TIER_STANDARD, tierFeeRaw, type Tier } from "../state/tiers.js";
import type { DojoClient } from "../dojo/client.js";

export interface MainMenuContext {
  /**
   * Null when the client is not configured (env vars missing). The menu shows
   * a helpful message in that case and the "Start Run" button stays disabled
   * until `scripts/deploy_dev.sh` has populated `client/.env.local`.
   */
  dojo: DojoClient | null;
  /** Approves the entry fee and submits `spawn(gameId, settings_id)` on-chain. */
  onOnlineSpawn: (tier: Tier) => Promise<void>;
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
    : "Dev env not bootstrapped — run scripts/deploy_dev.sh.";
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

  if (!ctx.dojo) {
    return col;
  }

  const dojo = ctx.dojo;
  let currentBalance = 0n;
  let busy = false;

  const setBusy = (on: boolean): void => {
    busy = on;
    mintBtn.disabled = on;
    startBtn.disabled = on;
    refreshAffordability();
  };

  const refreshAffordability = (): void => {
    if (busy) return;
    balanceLabel.textContent = `Balance: ${currentBalance.toLocaleString()} mLORDS`;
    const affordable = currentBalance >= TIER_STANDARD.entryFeeLords;
    startBtn.disabled = !affordable;
    startBtn.title = affordable
      ? ""
      : `Need ${TIER_STANDARD.entryFeeLords} mLORDS — mint more`;
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

  void reloadBalance();

  return col;
}
