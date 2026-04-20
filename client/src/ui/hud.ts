import { ABILITIES, type AbilityId } from "../state/constants.js";
import { canUseAbility, type CombatState } from "../state/combat.js";

export interface HudHandle {
  root: HTMLElement;
  refresh: (state: CombatState) => void;
  onAbility: (cb: (abilityId: AbilityId) => void) => void;
  onConfirm: (cb: () => void) => void;
  onReset: (cb: () => void) => void;
  onExit: (cb: () => void) => void;
}

export function createHud(parent: HTMLElement, initial: CombatState): HudHandle {
  const root = document.createElement("div");
  root.className = "hud";
  parent.appendChild(root);

  const topBar = document.createElement("div");
  topBar.className = "hud-top";
  root.appendChild(topBar);

  const tierBadge = document.createElement("div");
  tierBadge.className = "tier-badge";
  topBar.appendChild(tierBadge);

  const hpBlock = document.createElement("div");
  hpBlock.className = "resource";
  hpBlock.innerHTML = `<span class="label">HP</span><div class="bar"><div class="fill hp-fill"></div></div><span class="value hp-value"></span>`;
  topBar.appendChild(hpBlock);

  const staminaBlock = document.createElement("div");
  staminaBlock.className = "resource";
  staminaBlock.innerHTML = `<span class="label">STA</span><div class="bar"><div class="fill stamina-fill"></div></div><span class="value stamina-value"></span>`;
  topBar.appendChild(staminaBlock);

  const scoreBlock = document.createElement("div");
  scoreBlock.className = "score-block";
  topBar.appendChild(scoreBlock);

  const exitButton = document.createElement("button");
  exitButton.className = "hud-exit";
  exitButton.textContent = "Exit";
  topBar.appendChild(exitButton);

  const bottom = document.createElement("div");
  bottom.className = "hud-bottom";
  root.appendChild(bottom);

  const abilities = document.createElement("div");
  abilities.className = "abilities";
  bottom.appendChild(abilities);

  const abilityButtons: HTMLButtonElement[] = ABILITIES.map((ability, idx) => {
    const btn = document.createElement("button");
    btn.className = "ability";
    btn.dataset.abilityId = String(ability.id);
    btn.innerHTML = `<span class="ability-key">${idx + 1}</span><span class="ability-name">${ability.name}</span><span class="ability-cost">${ability.cost}</span>`;
    abilities.appendChild(btn);
    return btn;
  });

  const actions = document.createElement("div");
  actions.className = "actions";
  bottom.appendChild(actions);

  const resetBtn = document.createElement("button");
  resetBtn.className = "action reset";
  resetBtn.textContent = "Reset";
  actions.appendChild(resetBtn);

  const confirmBtn = document.createElement("button");
  confirmBtn.className = "action confirm";
  confirmBtn.textContent = "Confirm";
  actions.appendChild(confirmBtn);

  const refresh = (state: CombatState): void => {
    tierBadge.textContent = state.online
      ? `${state.run.tier.name} — online`
      : `${state.run.tier.name} — offline`;

    const hpFill = hpBlock.querySelector<HTMLElement>(".hp-fill")!;
    const hpValue = hpBlock.querySelector<HTMLElement>(".hp-value")!;
    hpFill.style.width = `${Math.max(0, (state.player.hp / state.player.maxHp) * 100)}%`;
    hpValue.textContent = `${state.player.hp} / ${state.player.maxHp}`;

    const staFill = staminaBlock.querySelector<HTMLElement>(".stamina-fill")!;
    const staValue = staminaBlock.querySelector<HTMLElement>(".stamina-value")!;
    staFill.style.width = `${Math.max(0, (state.run.stamina / state.run.maxStamina) * 100)}%`;
    staValue.textContent = `${state.run.stamina} / ${state.run.maxStamina}`;

    scoreBlock.textContent = `Score ${state.run.score} · Room ${state.run.roomsCleared + 1}`;

    for (const btn of abilityButtons) {
      const abilityId = Number(btn.dataset.abilityId) as AbilityId;
      btn.disabled = !canUseAbility(state, abilityId);
    }
  };

  refresh(initial);

  return {
    root,
    refresh,
    onAbility(cb) {
      for (const btn of abilityButtons) {
        btn.addEventListener("click", () => {
          const abilityId = Number(btn.dataset.abilityId) as AbilityId;
          cb(abilityId);
        });
      }
    },
    onConfirm(cb) {
      confirmBtn.addEventListener("click", () => cb());
    },
    onReset(cb) {
      resetBtn.addEventListener("click", () => cb());
    },
    onExit(cb) {
      exitButton.addEventListener("click", () => cb());
    },
  };
}
