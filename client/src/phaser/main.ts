import Phaser from 'phaser';
import { PhaserBridge } from './PhaserBridge';
import { BootScene } from './scenes/BootScene';
import { MainScene } from './scenes/MainScene';

export function createPhaserGame(parent: string, bridge: PhaserBridge): Phaser.Game {
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    parent,
    backgroundColor: '#080810',
    transparent: true,
    banner: false,
    dom: { createContainer: false },
    scale: {
      mode: Phaser.Scale.RESIZE,
    },
    scene: [BootScene, MainScene],
  });

  game.registry.set('bridge', bridge);
  game.sound.pauseOnBlur = false;
  bridge.setGame(game);
  return game;
}
