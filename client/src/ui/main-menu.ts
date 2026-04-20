import { TIERS, tierFeeRaw, type Tier } from "../state/tiers.js";
import type { DojoClient } from "../dojo/client.js";

export type MenuMode = "offline" | "online";
export type MenuCallback = (mode: MenuMode, tier: Tier) => void | Promise<void>;

export interface MainMenuContext {
  /** Null when the client is not configured (env vars missing) — online column shows a helpful message. */
  dojo: DojoClient | null;
  onEnter: MenuCallback;
  /** Called by the menu to pay + spawn on-chain. Must approve and submit spawn before resolving. */
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
  subtitle.textContent = "How deep can you go before the stamina runs out?";
  card.appendChild(subtitle);

  card.appendChild(buildOfflineColumn(ctx));
  card.appendChild(buildOnlineColumn(ctx));

  const note = document.createElement("p");
  note.className = "note";
  note.textContent = ctx.dojo
    ? "Online mode uses the shared dev burner. mLORDS mint is unrestricted for testing."
    : "Online disabled — run scripts/deploy_dev.sh to bootstrap the dev env.";
  card.appendChild(note);

  container.appendChild(card);
}

function buildOfflineColumn(ctx: MainMenuContext): HTMLElement {
  const col = document.createElement("div");
  col.className = "tier-column";

  const heading = document.createElement("h2");
  heading.textContent = "Offline";
  col.appendChild(heading);

  const info = document.createElement("p");
  info.className = "column-note";
  info.textContent = "No fee. Local combat skeleton.";
  col.appendChild(info);

  for (const tier of TIERS) {
    const btn = document.createElement("button");
    btn.className = `tier-button tier-${tier.name.toLowerCase()}`;
    btn.textContent = `${tier.name} — ${tier.stamina} stamina`;
    btn.addEventListener("click", () => {
      void ctx.onEnter("offline", tier);
    });
    col.appendChild(btn);
  }

  return col;
}

function buildOnlineColumn(ctx: MainMenuContext): HTMLElement {
  const col = document.createElement("div");
  col.className = "tier-column";

  const heading = document.createElement("h2");
  heading.textContent = "Online (dev)";
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

  const tierButtons: Array<{ tier: Tier; btn: HTMLButtonElement }> = [];
  for (const tier of TIERS) {
    const btn = document.createElement("button");
    btn.className = `tier-button tier-${tier.name.toLowerCase()}`;
    const fee = tier.entryFeeLords.toLocaleString();
    btn.textContent = `${tier.name} — ${tier.stamina} stamina · ${fee} mLORDS`;
    btn.disabled = !ctx.dojo;
    col.appendChild(btn);
    tierButtons.push({ tier, btn });
  }

  if (!ctx.dojo) {
    return col;
  }

  const dojo = ctx.dojo;
  let currentBalance = 0n;
  let busy = false;

  const setBusy = (on: boolean): void => {
    busy = on;
    mintBtn.disabled = on;
    for (const { btn } of tierButtons) btn.disabled = on;
    refreshAffordability();
  };

  const refreshAffordability = (): void => {
    if (busy) return;
    balanceLabel.textContent = `Balance: ${currentBalance.toLocaleString()} mLORDS`;
    for (const { tier, btn } of tierButtons) {
      const affordable = currentBalance >= tier.entryFeeLords;
      btn.disabled = !affordable;
      btn.title = affordable ? "" : `Need ${tier.entryFeeLords} mLORDS — mint more`;
    }
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

  for (const { tier, btn } of tierButtons) {
    btn.addEventListener("click", async () => {
      if (busy) return;
      setBusy(true);
      const originalLabel = btn.textContent ?? "";
      btn.textContent = "Paying fee...";
      try {
        await dojo.approveLords(tierFeeRaw(tier));
        btn.textContent = "Spawning...";
        await ctx.onOnlineSpawn(tier);
      } catch (err) {
        balanceLabel.textContent = `Spawn failed: ${(err as Error).message}`;
        btn.textContent = originalLabel;
        setBusy(false);
      }
    });
  }

  void reloadBalance();

  return col;
}
