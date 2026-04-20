import type { CombatState } from "../state/combat.js";

export function renderGameOver(
  container: HTMLElement,
  state: CombatState,
  onReturn: () => void,
): void {
  const overlay = document.createElement("div");
  overlay.className = "game-over";

  const card = document.createElement("div");
  card.className = "game-over-card";

  const title = document.createElement("h2");
  title.textContent = state.player.hp <= 0 ? "YOU DIED" : "OUT OF STAMINA";
  card.appendChild(title);

  const stats = document.createElement("p");
  stats.textContent = `${state.run.tier.name} run · score ${state.run.score} · ${state.run.roomsCleared} rooms cleared`;
  card.appendChild(stats);

  const btn = document.createElement("button");
  btn.textContent = "Back to menu";
  btn.addEventListener("click", () => {
    overlay.remove();
    onReturn();
  });
  card.appendChild(btn);

  overlay.appendChild(card);
  container.appendChild(overlay);
}
