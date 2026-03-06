import Phaser from 'phaser';
import { PhaserBridge } from './PhaserBridge';
import { BootScene } from './scenes/BootScene';
import { MainScene } from './scenes/MainScene';
import { GAME_HEIGHT, GAME_WIDTH } from './utils/layout';

export function createPhaserGame(parent: string, bridge: PhaserBridge): Phaser.Game {
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    parent,
    backgroundColor: '#080810',
    transparent: true,
    banner: false,
    dom: { createContainer: false },
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
      width: GAME_WIDTH,
      height: GAME_HEIGHT,
    },
    scene: [BootScene, MainScene],
  });

  game.registry.set('bridge', bridge);
  bridge.setGame(game);
  return game;
}
