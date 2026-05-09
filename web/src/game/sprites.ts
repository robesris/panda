// Asset manifest + preloader. All paths are served from /assets/* via Vite's
// public/ directory.
import { Assets, Texture } from "pixi.js";

const PLAYER_WALK_FRAMES = 9;

export const SPRITES = {
  player: {
    walk: Array.from({ length: PLAYER_WALK_FRAMES }, (_, i) => `/assets/player/walk-${i + 1}.gif`),
    idle: "/assets/player/panda-revised.png",
  },
  enemies: {
    watermelonReg: "/assets/enemies/watermelon-reg.png",
    watermelonHit: "/assets/enemies/watermelon-hit.png",
    rocks: [1, 2, 3, 4].map((i) => `/assets/enemies/rocks${i}.png`),
  },
  projectile: {
    seed: "/assets/projectile/seed.png",
  },
  bg: {
    stars: "/assets/bg/stars.png",
  },
} as const;

export interface LoadedSprites {
  playerWalk: Texture[];
  playerIdle: Texture;
  watermelonReg: Texture;
  watermelonHit: Texture;
  rocks: Texture[];
  seed: Texture;
  bgStars: Texture;
}

export async function loadSprites(): Promise<LoadedSprites> {
  const urls = [
    ...SPRITES.player.walk,
    SPRITES.player.idle,
    SPRITES.enemies.watermelonReg,
    SPRITES.enemies.watermelonHit,
    ...SPRITES.enemies.rocks,
    SPRITES.projectile.seed,
    SPRITES.bg.stars,
  ];
  const map = await Assets.load<Texture>(urls);
  return {
    playerWalk: SPRITES.player.walk.map((u) => map[u]),
    playerIdle: map[SPRITES.player.idle],
    watermelonReg: map[SPRITES.enemies.watermelonReg],
    watermelonHit: map[SPRITES.enemies.watermelonHit],
    rocks: SPRITES.enemies.rocks.map((u) => map[u]),
    seed: map[SPRITES.projectile.seed],
    bgStars: map[SPRITES.bg.stars],
  };
}
