// Audio-driven sandbox. Demonstrates feature-driven spawning end-to-end so we
// can verify the engine before porting the real game logic.
//
//   flux > HI_FLUX           → small enemy (rock) drifts in (pitch sets Y)
//   flux > BEAT_FLUX & peak  → watermelon enemy spawns and pulses
//   level                    → background brightness

import { AnimatedSprite, Application, Container, Sprite, Text, TilingSprite } from "pixi.js";
import type { FrameFeatures } from "../audio/engine";
import { loadSprites, type LoadedSprites } from "./sprites";

export interface SandboxThresholds {
  hiFlux: number;
  beatFlux: number;
}

interface Mover {
  sprite: Sprite;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  /** Used for beat-enemy pulse animation. */
  pulse: number;
}

const STAGE_W = 800;
const STAGE_H = 500;

export class Sandbox {
  app: Application;
  private world: Container;
  private bg!: TilingSprite;
  private player!: AnimatedSprite;
  private movers: Mover[] = [];
  private statText: Text;
  private sprites!: LoadedSprites;
  thresholds: SandboxThresholds = { hiFlux: 0.6, beatFlux: 1.5 };
  private lastFlashTicks = 0;

  constructor() {
    this.app = new Application();
    this.world = new Container();
    this.statText = new Text({
      text: "",
      style: { fill: 0x9ff0f6, fontFamily: "ui-monospace, monospace", fontSize: 12 },
    });
  }

  async init(canvas: HTMLCanvasElement) {
    await this.app.init({
      canvas,
      width: STAGE_W,
      height: STAGE_H,
      background: 0x0a2330,
      antialias: false, // pixel-art assets
    });
    this.sprites = await loadSprites();

    // Tiled starfield background.
    this.bg = new TilingSprite({
      texture: this.sprites.bgStars,
      width: STAGE_W,
      height: STAGE_H,
    });
    this.app.stage.addChild(this.bg);

    this.app.stage.addChild(this.world);

    // Player: animated walk cycle, anchored bottom-left of foot.
    this.player = new AnimatedSprite(this.sprites.playerWalk);
    this.player.animationSpeed = 0.18;
    this.player.anchor.set(0.5, 1);
    this.player.x = 80;
    this.player.y = STAGE_H - 60;
    this.player.scale.set(2);
    this.player.play();
    this.world.addChild(this.player);

    this.statText.x = 8;
    this.statText.y = 8;
    this.app.stage.addChild(this.statText);

    this.app.ticker.add(() => this.update());
  }

  feed(f: FrameFeatures) {
    // Background scroll + brightness from level.
    const brightness = Math.min(1, 0.4 + f.level * 6);
    this.bg.tint = rgbTint(brightness);
    this.bg.tilePosition.x -= 0.5 + f.level * 4;

    if (f.fluxPeak && f.flux > this.thresholds.beatFlux) {
      this.lastFlashTicks = 8;
      this.spawnBeatEnemy(f);
    } else if (f.flux > this.thresholds.hiFlux) {
      if (Math.random() < 0.25) this.spawnSkitter(f);
    }

    this.statText.text =
      `flux ${f.flux.toFixed(2)}  peak ${f.fluxPeak ? "*" : " "}  ` +
      `pitch ${f.pitch.toString().padStart(2, " ")}  ` +
      `Hz ${f.dominantHz.toFixed(0).padStart(5, " ")}  ` +
      `level ${f.level.toFixed(2)}  ` +
      `live ${this.movers.length}`;
  }

  private spawnSkitter(f: FrameFeatures) {
    const tex = this.sprites.rocks[Math.floor(Math.random() * this.sprites.rocks.length)];
    const s = new Sprite(tex);
    s.anchor.set(0.5);
    s.scale.set(2);
    s.x = STAGE_W + 20;
    s.y = pitchToY(f.pitch, 80, STAGE_H - 100);
    s.rotation = Math.random() * Math.PI * 2;
    this.world.addChild(s);
    this.movers.push({
      sprite: s,
      vx: -3 - Math.random() * 2,
      vy: (Math.random() - 0.5) * 0.6,
      life: 0,
      maxLife: 320,
      pulse: 0,
    });
  }

  private spawnBeatEnemy(f: FrameFeatures) {
    const s = new Sprite(this.sprites.watermelonReg);
    s.anchor.set(0.5);
    const baseScale = 0.25 + Math.min(0.5, f.flux * 0.1);
    s.scale.set(baseScale);
    s.x = STAGE_W + 30;
    s.y = pitchToY(f.pitch, 60, STAGE_H - 80);
    this.world.addChild(s);
    this.movers.push({
      sprite: s,
      vx: -1.5 - Math.random() * 0.8,
      vy: 0,
      life: 0,
      maxLife: 460,
      pulse: 1,
    });
  }

  private update() {
    // Flash overlay decays via stage alpha hack on a temp sprite — use bg tint
    // pulse instead for simplicity. The flash readout is folded into bg.tint.
    if (this.lastFlashTicks > 0) this.lastFlashTicks--;

    for (let i = this.movers.length - 1; i >= 0; i--) {
      const m = this.movers[i];
      m.sprite.x += m.vx;
      m.sprite.y += m.vy;
      m.sprite.rotation += 0.02;
      m.life++;
      if (m.pulse > 0) {
        const baseScale = m.sprite.scale.x / (1 + m.pulse * 0.15);
        m.pulse *= 0.85;
        m.sprite.scale.set(baseScale * (1 + m.pulse * 0.15));
      }
      if (m.life > m.maxLife || m.sprite.x < -60) {
        this.world.removeChild(m.sprite);
        m.sprite.destroy();
        this.movers.splice(i, 1);
      }
    }
  }
}

function pitchToY(pitch: number, top: number, bottom: number): number {
  if (pitch < 0) return (top + bottom) / 2;
  // Higher pitch → higher on screen. Pitch range is 0..36.
  const t = 1 - pitch / 36;
  return top + t * (bottom - top);
}

function rgbTint(brightness: number): number {
  const r = Math.floor(0x60 + 0x60 * brightness);
  const g = Math.floor(0x80 + 0x70 * brightness);
  const b = Math.floor(0x90 + 0x60 * brightness);
  return (r << 16) | (g << 8) | b;
}
