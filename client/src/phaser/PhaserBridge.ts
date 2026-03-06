import Phaser from 'phaser';

export interface AthanorHero {
  hero_id: number;
  hp: number;
  max_hp: number;
  power: number;
  regen_per_sec: number;
  status: number;
  return_at: number;
  death_depth: number;
  pending_gold: number;
}

export interface AthanorSession {
  game_id: number;
  gold: number;
  discovered_count: number;
  hero_count: number;
  game_over: boolean;
  started_at: number;
}

export interface HeroChangePayload {
  hero: AthanorHero;
  previousHero: AthanorHero | null;
}

export class PhaserBridge extends Phaser.Events.EventEmitter {
  private gameInstance: Phaser.Game | null = null;
  private _focusedHeroId = 0;
  private _selectedHeroId = -1;
  private previousHeroes = new Map<number, AthanorHero>();
  private previousSession: AthanorSession | null = null;

  setGame(game: Phaser.Game | null): void {
    this.gameInstance = game;
  }

  getGame(): Phaser.Game | null {
    return this.gameInstance;
  }

  get focusedHeroId(): number {
    return this._focusedHeroId;
  }

  get selectedHeroId(): number {
    return this._selectedHeroId;
  }

  setFocusedHero(heroId: number): void {
    if (this._focusedHeroId === heroId) return;
    this._focusedHeroId = heroId;
    this.emit('focusedHeroChange', heroId);
  }

  selectHero(heroId: number): void {
    this._selectedHeroId = heroId;
    this.emit('heroSelected', heroId);
  }

  deselectHero(): void {
    this._selectedHeroId = -1;
    this.emit('heroSelected', -1);
  }

  updateHeroes(heroes: AthanorHero[]): void {
    for (const hero of heroes) {
      const prev = this.previousHeroes.get(hero.hero_id) ?? null;
      if (!prev || this.didHeroChange(prev, hero)) {
        this.emit('heroChange', { hero, previousHero: prev } satisfies HeroChangePayload);
      }
      this.previousHeroes.set(hero.hero_id, { ...hero });
    }

    const activeIds = new Set(heroes.map((h) => h.hero_id));
    for (const id of this.previousHeroes.keys()) {
      if (!activeIds.has(id)) {
        this.previousHeroes.delete(id);
      }
    }

    this.emit('heroesUpdated', heroes);
  }

  updateSession(session: AthanorSession): void {
    const prev = this.previousSession;

    if (prev && !prev.game_over && session.game_over) {
      this.emit('gameOver', session);
    }

    if (prev && session.discovered_count > prev.discovered_count) {
      this.emit('discovery', session);
    }

    this.previousSession = { ...session };
    this.emit('sessionChange', session);
  }

  updateZone(zoneId: number | null): void {
    this.emit('zoneChange', zoneId);
  }

  notifyBootComplete(): void {
    this.emit('bootComplete');
  }

  playCraftEffect(discovered: boolean): void {
    this.emit('craftResult', { discovered });
  }

  private didHeroChange(prev: AthanorHero, next: AthanorHero): boolean {
    return (
      prev.status !== next.status ||
      prev.hp !== next.hp ||
      prev.death_depth !== next.death_depth
    );
  }
}
