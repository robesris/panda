// Three-state button (up/over/hit) backed by three textures.
import { Sprite, Texture } from "pixi.js";

export interface ButtonTextures {
  up: Texture;
  over: Texture;
  hit: Texture;
}

export class Button extends Sprite {
  private tex: ButtonTextures;
  private isDown = false;
  private isOver = false;
  private _enabled = true;
  onClick: () => void = () => {};

  constructor(tex: ButtonTextures) {
    super(tex.up);
    this.tex = tex;
    this.eventMode = "static";
    this.cursor = "pointer";
    this.anchor.set(0.5);
    this.on("pointerover", () => { this.isOver = true; this.refresh(); });
    this.on("pointerout", () => { this.isOver = false; this.isDown = false; this.refresh(); });
    this.on("pointerdown", () => { this.isDown = true; this.refresh(); });
    this.on("pointerup", () => {
      const wasDown = this.isDown;
      this.isDown = false;
      this.refresh();
      if (wasDown && this._enabled) this.onClick();
    });
    this.on("pointerupoutside", () => { this.isDown = false; this.refresh(); });
  }

  set enabled(v: boolean) {
    this._enabled = v;
    this.alpha = v ? 1 : 0.45;
    this.cursor = v ? "pointer" : "default";
    this.eventMode = v ? "static" : "none";
    this.refresh();
  }
  get enabled() { return this._enabled; }

  private refresh() {
    if (!this._enabled) { this.texture = this.tex.up; return; }
    if (this.isDown) this.texture = this.tex.hit;
    else if (this.isOver) this.texture = this.tex.over;
    else this.texture = this.tex.up;
  }
}
