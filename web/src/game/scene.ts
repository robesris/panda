// Phase A gameplay scene: mouse-controlled flying panda over scrolling parallax,
// click/space fires seed bullets to the right, HUD shows score + life + audio
// normalization status. No enemies yet — that's Phase B.
//
// Faithful-to-original behaviors:
// - Player follows mouseX/mouseY with a 5px edge clamp.
// - Animation states: 'run' when near the ground, 'fly_forward' when moving
//   right (or stationary), 'fly_back' for a brief window after moving left.
// - Bullets travel right at vx=20 from the player's gun barrel.
// - Background scroll layers: stars (slowest), mountains (medium), ground
//   (fastest). The original ramps GROUND_SPEED from 1 to 60 over ~10s.

import {
  AnimatedSprite,
  Container,
  Graphics,
  Sprite,
  Text,
  TilingSprite,
} from "pixi.js";
import type { FrameFeatures } from "../audio/engine";
import type { LoadedSprites } from "./sprites";

export const STAGE_W = 800;
export const STAGE_H = 500;

const FPS = 30;
const GROUND_SPEED = 60;
const PLAYER_MAX_LIFE = 100;
const FLY_BACK_HOLD = FPS / 2; // frames to keep fly_back after moving left

// Spawn thresholds in normalized-flux units (mean=1.0 after lock-in).
// Ratios from original constants: TARGET_AVG_FLUX=27000, BEAT_FLUX=100,
// HI_FLUX=60, LO_FLUX=10 (with the in-game /1000 scaling).
export const FLUX_LO = 10000 / 27000;
export const FLUX_HI = 60000 / 27000;
export const FLUX_BEAT = 100000 / 27000;

interface Bullet {
  s: Sprite;
  vx: number;
  vy: number;
  hp: number;
}

export interface InputState {
  mouseX: number;
  mouseY: number;
  mouseDown: boolean;
  spaceDown: boolean;
}

export class GameScene {
  container = new Container();

  private world = new Container();
  private hud = new Container();
  private bgStars!: TilingSprite;       // slowest parallax (sky-stars)
  private bgMountains!: TilingSprite;   // medium parallax
  private bgGround!: TilingSprite;      // fastest, foreground
  private skyFill!: Graphics;
  private currentGroundSpeed = 1;

  private player!: AnimatedSprite;
  private playerFlyFwd!: Sprite;
  private playerFlyBack!: Sprite;
  private playerState: "run" | "fly_forward" | "fly_back" = "fly_forward";
  private flyBackTimer = 0;

  private bullets: Bullet[] = [];
  private fireCooldown = 0; // hold-to-fire (machine-gun) cadence

  private hudScore!: Text;
  private hudLife!: Text;
  private hudAudio!: Text;
  private hudHelp!: Text;
  private beatPulse = 0;

  private sprites!: LoadedSprites;

  build(sprites: LoadedSprites) {
    this.sprites = sprites;

    // Sky fill: solid color since the original bg-sky.png .dat fails to decode.
    this.skyFill = new Graphics();
    this.skyFill.rect(0, 0, STAGE_W, STAGE_H).fill(0x6cb6c7);
    this.container.addChild(this.skyFill);

    // Slowest parallax — bg-stars-big (twinkly stars).
    this.bgStars = new TilingSprite({
      texture: sprites.bgStarsBig,
      width: STAGE_W,
      height: STAGE_H * 0.7,
    });
    this.bgStars.alpha = 0.6;
    this.container.addChild(this.bgStars);

    // Medium parallax — mountain silhouette.
    this.bgMountains = new TilingSprite({
      texture: sprites.bgMountains,
      width: STAGE_W,
      height: 120,
    });
    this.bgMountains.y = STAGE_H - 120 - 67;
    this.container.addChild(this.bgMountains);

    // Foreground — ground.
    this.bgGround = new TilingSprite({
      texture: sprites.bgGround,
      width: STAGE_W,
      height: 67,
    });
    this.bgGround.y = STAGE_H - 67;
    this.container.addChild(this.bgGround);

    this.container.addChild(this.world);

    // Player. Three sprites stacked at the same position; we toggle `visible`.
    this.player = new AnimatedSprite(sprites.playerWalk);
    this.player.animationSpeed = 0.18;
    this.player.anchor.set(0.5, 1);
    this.player.scale.set(1.5);
    this.player.play();

    this.playerFlyFwd = new Sprite(sprites.playerFlyFwd);
    this.playerFlyFwd.anchor.set(0.5, 1);
    this.playerFlyFwd.scale.set(1.5);

    this.playerFlyBack = new Sprite(sprites.playerFlyBack);
    this.playerFlyBack.anchor.set(0.5, 1);
    this.playerFlyBack.scale.set(1.5);

    this.world.addChild(this.player);
    this.world.addChild(this.playerFlyFwd);
    this.world.addChild(this.playerFlyBack);
    this.player.x = this.playerFlyFwd.x = this.playerFlyBack.x = 200;
    this.player.y = this.playerFlyFwd.y = this.playerFlyBack.y = STAGE_H / 2;
    this.applyPlayerState();

    this.buildHud();
  }

  private buildHud() {
    const monoStyle = {
      fill: 0xfff5b1,
      fontFamily: "ui-monospace, monospace",
      fontSize: 14,
      fontWeight: "bold" as const,
    };
    this.hudScore = new Text({ text: "SCORE 0000000", style: monoStyle });
    this.hudScore.x = 200;
    this.hudScore.y = 8;
    this.hud.addChild(this.hudScore);

    this.hudLife = new Text({
      text: `LIFE ${PLAYER_MAX_LIFE}`,
      style: { ...monoStyle, fill: 0xff9bb5 },
    });
    this.hudLife.x = 8;
    this.hudLife.y = 8;
    this.hud.addChild(this.hudLife);

    this.hudAudio = new Text({
      text: "WARMING UP…",
      style: { ...monoStyle, fontSize: 11, fill: 0x9ff0f6 },
    });
    this.hudAudio.x = STAGE_W - 8;
    this.hudAudio.y = 8;
    this.hudAudio.anchor.set(1, 0);
    this.hud.addChild(this.hudAudio);

    this.hudHelp = new Text({
      text: "MOVE: MOUSE   FIRE: CLICK / SPACE",
      style: { ...monoStyle, fontSize: 11, fill: 0xc8d8e0 },
    });
    this.hudHelp.x = STAGE_W / 2;
    this.hudHelp.y = STAGE_H - 16;
    this.hudHelp.anchor.set(0.5, 0);
    this.hud.addChild(this.hudHelp);

    this.container.addChild(this.hud);
  }

  /** Audio-frame data, called once per render tick when the scene is active. */
  feed(f: FrameFeatures) {
    // Modulate background brightness from level.
    const bright = Math.min(1, 0.5 + f.level * 5);
    this.skyFill.alpha = 1;
    this.skyFill.tint = mixColor(0x113745, 0x6cb6c7, bright);
    this.bgStars.alpha = Math.min(0.85, 0.5 + f.level * 3);

    // Beat pulse: the only audio→visual feedback in Phase A. A faint
    // white flash on flux peaks above the beat threshold.
    if (f.fluxPeak && f.flux > FLUX_BEAT) this.beatPulse = 1;

    const elapsed = f.elapsedSec;
    const norm = f.normalized;
    let line = norm
      ? `LOCKED  flux ${f.flux.toFixed(2)}  int ${f.intensity.toFixed(2)}  pitch ${pad(f.pitch, 2)}`
      : `WARM-UP ${elapsed.toFixed(1)}s  flux ${f.flux.toFixed(2)}`;
    if (f.fluxPeak && f.flux > FLUX_BEAT) line += "  *BEAT*";
    this.hudAudio.text = line;
  }

  /** Per-frame physics + input. Called every ticker tick (audio or no audio). */
  update(input: InputState, dt: number) {
    this.movePlayer(input);
    this.moveBullets();
    this.scrollBackground(dt);
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (this.beatPulse > 0) {
      this.skyFill.tint = mixColor(this.skyFill.tint as number, 0xffffff, this.beatPulse * 0.3);
      this.beatPulse *= 0.85;
    }
  }

  private movePlayer(input: InputState) {
    if (input.mouseX <= 5 || input.mouseY <= 5) return; // out of canvas

    const prevX = this.player.x;
    const targetX = clamp(input.mouseX, 5, STAGE_W - 5);
    const targetY = clamp(input.mouseY, 5, STAGE_H - 5);

    let nextState: typeof this.playerState;
    if (targetY > STAGE_H - 90) {
      nextState = "run";
    } else if (targetX < prevX - 0.5) {
      nextState = "fly_back";
      this.flyBackTimer = FLY_BACK_HOLD;
    } else if (targetX > prevX + 0.5) {
      nextState = "fly_forward";
    } else if (this.flyBackTimer > 0) {
      this.flyBackTimer--;
      nextState = this.playerState;
    } else {
      nextState = "fly_forward";
    }

    this.player.x = this.playerFlyFwd.x = this.playerFlyBack.x = targetX;
    this.player.y = this.playerFlyFwd.y = this.playerFlyBack.y = targetY;

    if (nextState !== this.playerState) {
      this.playerState = nextState;
      this.applyPlayerState();
    }
  }

  private applyPlayerState() {
    this.player.visible = this.playerState === "run";
    this.playerFlyFwd.visible = this.playerState === "fly_forward";
    this.playerFlyBack.visible = this.playerState === "fly_back";
  }

  /**
   * External call to fire a bullet (from main.ts on mousedown / space-down).
   * The consumer translates press events into discrete shoot calls; we apply
   * a tiny cooldown here only to dampen accidental double-fires.
   */
  shoot() {
    if (this.fireCooldown > 0) return;
    const s = new Sprite(this.sprites.seed);
    s.anchor.set(0.5);
    s.scale.set(1.5);
    s.x = this.player.x + 30;
    s.y = this.player.y - 22;
    this.world.addChild(s);
    this.bullets.push({ s, vx: 20, vy: 0, hp: 1 });
    this.fireCooldown = 2;
  }

  private moveBullets() {
    for (let i = this.bullets.length - 1; i >= 0; i--) {
      const b = this.bullets[i];
      b.s.x += b.vx;
      b.s.y += b.vy;
      if (b.s.x > STAGE_W + 20 || b.s.y > STAGE_H + 20) {
        this.world.removeChild(b.s);
        b.s.destroy();
        this.bullets.splice(i, 1);
      }
    }
  }

  private scrollBackground(dt: number) {
    if (this.currentGroundSpeed < GROUND_SPEED) {
      this.currentGroundSpeed += GROUND_SPEED / (10 * 60); // ramp over ~10s
    }
    this.bgStars.tilePosition.x -= 0.25 * dt;
    this.bgMountains.tilePosition.x -= 1 * dt;
    this.bgGround.tilePosition.x -= this.currentGroundSpeed * dt;
  }
}

function clamp(v: number, lo: number, hi: number) {
  return v < lo ? lo : v > hi ? hi : v;
}

function pad(n: number, w: number) {
  return n.toString().padStart(w, " ");
}

function mixColor(a: number, b: number, t: number) {
  const ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
  const br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
  const r = Math.round(ar + (br - ar) * t);
  const g = Math.round(ag + (bg - ag) * t);
  const bch = Math.round(ab + (bb - ab) * t);
  return (r << 16) | (g << 8) | bch;
}
