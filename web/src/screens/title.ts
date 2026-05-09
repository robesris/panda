// Title screen: branding + audio source selection.
//
// Original Flash version had a YouTube URL field plus four song-preset
// buttons (BAD ROMANCE / BURNING HEAT / LE DISKO / TOO MUCH). We can't
// ship YouTube audio and don't have the original tracks, so the web build
// replaces both with file-upload + microphone — same idea, just locally.

import { Container, Graphics, Sprite, Text } from "pixi.js";
import type { LoadedSprites } from "../game/sprites";
import { Button } from "./button";

const STAGE_W = 800;
const STAGE_H = 500;

export class TitleScreen {
  container = new Container();
  onPickFile: () => void = () => {};
  onPickMic: () => void = () => {};
  private status: Text;
  private goBtn!: Button;
  private micBtn!: Button;

  constructor() {
    this.status = new Text({
      text: "",
      style: {
        fill: 0xe6f6fa,
        fontFamily: "ui-monospace, monospace",
        fontSize: 13,
        align: "center",
      },
    });
  }

  build(sprites: LoadedSprites) {
    // Background sunburst.
    const bg = new Sprite(sprites.titleBg);
    bg.width = STAGE_W;
    bg.height = STAGE_H;
    this.container.addChild(bg);

    // Dim panel covering the YouTube text + input area baked into bg.png so
    // we can put fresh copy over it.
    const panel = new Graphics();
    panel.rect(0, 230, STAGE_W, 200).fill({ color: 0x07202b, alpha: 0.85 });
    this.container.addChild(panel);

    // Game logo at top.
    const logo = new Sprite(sprites.titleLogo);
    logo.anchor.set(0.5, 0);
    logo.x = STAGE_W / 2;
    logo.y = 24;
    logo.scale.set(0.85);
    this.container.addChild(logo);

    // Decorative panda peering in from the right.
    const panda = new Sprite(sprites.titlePanda);
    panda.anchor.set(1, 1);
    panda.x = STAGE_W - 8;
    panda.y = STAGE_H - 8;
    panda.scale.set(0.7);
    this.container.addChild(panda);

    // Tagline above the buttons.
    const tagline = new Text({
      text: "YOUR MUSIC DETERMINES THE GAME'S BEHAVIOR",
      style: {
        fill: 0xffe9a8,
        fontFamily: "helvetica, arial, sans-serif",
        fontSize: 16,
        fontWeight: "bold",
        letterSpacing: 1,
      },
    });
    tagline.anchor.set(0.5);
    tagline.x = STAGE_W / 2;
    tagline.y = 252;
    this.container.addChild(tagline);

    // GO button = file picker.
    this.goBtn = new Button(sprites.btnGo);
    this.goBtn.x = STAGE_W / 2 - 120;
    this.goBtn.y = 340;
    this.goBtn.scale.set(1.4);
    this.goBtn.onClick = () => this.onPickFile();
    this.container.addChild(this.goBtn);
    const goLabel = labelText("LOAD AUDIO FILE");
    goLabel.x = this.goBtn.x;
    goLabel.y = this.goBtn.y + 60;
    this.container.addChild(goLabel);

    // Mic button (re-uses the yellow rectangular Win button as a generic CTA).
    this.micBtn = new Button(sprites.btnWin);
    this.micBtn.x = STAGE_W / 2 + 120;
    this.micBtn.y = 340;
    this.micBtn.scale.set(0.7);
    this.micBtn.onClick = () => this.onPickMic();
    this.container.addChild(this.micBtn);
    const micLabel = labelText("USE MICROPHONE");
    micLabel.x = this.micBtn.x;
    micLabel.y = this.micBtn.y + 36;
    this.container.addChild(micLabel);

    // Status line under both buttons.
    this.status.anchor.set(0.5);
    this.status.x = STAGE_W / 2;
    this.status.y = 460;
    this.container.addChild(this.status);
  }

  setStatus(text: string) {
    this.status.text = text;
  }

  setEnabled(v: boolean) {
    this.goBtn.enabled = v;
    this.micBtn.enabled = v;
  }
}

function labelText(text: string): Text {
  const t = new Text({
    text,
    style: {
      fill: 0xe6f6fa,
      fontFamily: "ui-monospace, monospace",
      fontSize: 11,
      letterSpacing: 1,
    },
  });
  t.anchor.set(0.5);
  return t;
}
