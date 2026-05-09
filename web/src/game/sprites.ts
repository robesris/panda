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
  title: {
    bg: "/assets/title/bg.png",
    logo: "/assets/title/title.png",
    panda: "/assets/title/panda.png",
    btnGo: {
      up: "/assets/title/btn-go-up.png",
      over: "/assets/title/btn-go-over.png",
      hit: "/assets/title/btn-go-hit.png",
    },
    btnAgain: {
      up: "/assets/title/btn-again-up.png",
      over: "/assets/title/btn-again-over.png",
      hit: "/assets/title/btn-again-hit.png",
    },
    btnWin: {
      up: "/assets/title/btn-win-light.png",
      over: "/assets/title/btn-win-over.png",
      hit: "/assets/title/btn-win-hit.png",
    },
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
  titleBg: Texture;
  titleLogo: Texture;
  titlePanda: Texture;
  btnGo: { up: Texture; over: Texture; hit: Texture };
  btnAgain: { up: Texture; over: Texture; hit: Texture };
  btnWin: { up: Texture; over: Texture; hit: Texture };
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
    SPRITES.title.bg,
    SPRITES.title.logo,
    SPRITES.title.panda,
    SPRITES.title.btnGo.up, SPRITES.title.btnGo.over, SPRITES.title.btnGo.hit,
    SPRITES.title.btnAgain.up, SPRITES.title.btnAgain.over, SPRITES.title.btnAgain.hit,
    SPRITES.title.btnWin.up, SPRITES.title.btnWin.over, SPRITES.title.btnWin.hit,
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
    titleBg: map[SPRITES.title.bg],
    titleLogo: map[SPRITES.title.logo],
    titlePanda: map[SPRITES.title.panda],
    btnGo: triple(map, SPRITES.title.btnGo),
    btnAgain: triple(map, SPRITES.title.btnAgain),
    btnWin: triple(map, SPRITES.title.btnWin),
  };
}

function triple(map: Record<string, Texture>, set: { up: string; over: string; hit: string }) {
  return { up: map[set.up], over: map[set.over], hit: map[set.hit] };
}
