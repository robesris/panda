package{

	import com.adobe.images.JPGEncoder;
	import com.adobe.images.PNGEncoder;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.*;
	import flash.events.KeyboardEvent;
	import flash.filters.*;
	import flash.filters.BitmapFilter;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.net.navigateToURL;
	import flash.text.TextField;
	import flash.ui.Keyboard;
	import flash.ui.Mouse;
	import flash.utils.ByteArray;

	
	public class gameAudioStuff extends MovieClip{
		var game_over:Boolean;
		
		var pctLoaded:String = "00%";
		const MP3_PORTION = 0.75
		
		const FPS:int = 30;
		const LOOKAHEAD = 5;
		var ALFframeBuffer = new Array();
		const START_COUNT_SECONDS:int = 15;
		const END_COUNT_SECONDS:int = 20;
		var songLength:Number;
		var nowOnBeat = false;
		
		var ls:LoseFull = null;
		var ws:WinFull = null;
		
		const SW = 800;
		const SH = 500;
		
		const GROUND_SPEED = 60;
		var currentGroundSpeed:Number;
		
		// Player constants
		const INVINCIBLE = false;
		const PLAYER_MAX_LIFE:int = 100;
		const PLAYER_HIT_WIDTH = 37;
		const PLAYER_HIT_HEIGHT = 40;
		
		const HI_FLUX:int = 60;
		const LO_FLUX:int = 10;
		const TUNE_FLUX = 60;
		const BEAT_FLUX:int = 100;
		//const BEAT_FLUX:int = 120;
		const HI_INTENSITY:int = 800;
		const LO_INTENSITY:int = 40;
		const TARGET_AVG_INTENSITY = 5000;
		const TARGET_AVG_FLUX = 27000;
		const GREEN_DISC = 1;
		const RED_DISC = 2;
		const BLUE_DISC = 3;
		const ZIG_ZAG = 4;
		const POPUP = 5;
		const SEED_BULLET = 6;
		
		var enemy_escaped = false;
		
		// States
		const MOVE = 1;
		const SHAKE = 2;
		var zig_pos = 0;
		
		const UP = new Point(0, 1);
		const RIGHT = new Point(-1, 0);
		const DOWN = new Point(0, -1);
		const LEFT = new Point(1, 0);

		const INTENSITY_LINE = false;
		const FLUX_LINE = false;
		const ROLLOFF_LINE = false;

		const INTENSITY_VAL = 0;
		const FLUX_VAL = 1;
		const PITCH = 2;
		
		var current_frame_num:int;
		var current_frame:Array;
		var current_flux:Number;
		var current_intensity:Number;
		var current_pitch:Number;
		
		var sumIntensity:Number = 0;
		var hiIntensity = 0;
		var loIntensity = Infinity;
		var avgIntensity:Number = 0;
		var adjustIntensity:Number = 0;
		
		var sumFlux:Number = 0;
		var hiFlux = 0;
		var loFlux = Infinity;
		var avgFlux = 0;
		var adjustFlux:Number = 1;

		// Sounds
		var lf_boss_mp3_req:URLRequest = new URLRequest('./lf_boss.mp3');
		var introMusic:Sound = new Sound(lf_boss_mp3_req);
		var bossHitSound:BossHitSound = new BossHitSound();
		var playerShootSound:playerShootQuietWAV = new playerShootQuietWAV();
		var discExplodeSound:discExplodeWAV = new discExplodeWAV();
		var powerUpCollectSound:powerUpCollectWAV = new powerUpCollectWAV;
		var introMusicChannel:SoundChannel;
		var introMusicVolControl:SoundTransform;
		
		var myALF:ALF;
		var songLoaded:Boolean;
		
		private var intensity:Number;
		private var flux:Number;

		// Fonts
		var fontMap:Fonts = new Fonts();
		var fontMapMedium:FontsMedium = new FontsMedium();
		var fontMapSmall:FontsSmall = new FontsSmall();
		var fontMapTiny:FontsTiny = new FontsTiny();
		const SMALL = 0;
		const MEDIUM = 1;
		const LARGE = 2;
		const TINY = 3;
		const LETTER_WIDTH = 32;
		const LETTER_HEIGHT = LETTER_WIDTH;
		const MEDIUM_LW = 16;
		const MEDIUM_LH = MEDIUM_LW;
		const SMALL_LW = 13;
		const SMALL_LH = SMALL_LW;
		const TINY_LW = 8;
		const TINY_LH = TINY_LW;
		
		const INSTR_1:Sprite = vgText("USE MOUSE TO MOVE");
		const INSTR_2:Sprite = vgText("MOUSE BUTTON OR SPACE SHOOTS!");
		const POWER_UP_MESSAGE:Sprite = vgText("SHOOT ENEMIES FOR POWER UPS");
		const PUM2:Sprite = vgText("WHILE YOUR SONG LOADS!");
		//const SCORE_LABEL:Sprite = vgText("SCORE ", MEDIUM, 200, 10);
		const SCORE_LABEL:ScoreLabel = new ScoreLabel();
		//const LIFE_LABEL:Sprite = vgText("LIFE ", MEDIUM, 10, 10);
		const LIFE_LABEL:PandaIcon = new PandaIcon();
		
		var scoreSprite:Sprite = vgText("0000000", MEDIUM, 200 + SCORE_LABEL.width, 10);
		var lifeSprite:Sprite = vgText(padZeros(PLAYER_MAX_LIFE, 3), MEDIUM, 10 + LIFE_LABEL.width, 10);
		var loadSprite:Sprite = vgText(pctLoaded, LARGE, SW / 2 - LETTER_WIDTH * 3 / 2, PUM2.y + 10);
		
		// In terms of grid position, not pixel coordinates
		const A_POS_X = 13;
		const A_POS_Y = 45;
		const FONT_BITMAP_WIDTH = 28;
		
		// Display
		var vidFrame:uint = 0;
		
		// Lines
		var line:MovieClip;
		var fluxLine:MovieClip;
		var rolloffLine:MovieClip;
		var brightnessLine:MovieClip;
		var bandwidthLine:MovieClip;
		
		// Line arrays
		var lineArr:Array;
		var brightnessLineArr:Array;
		var bandwidthLineArr:Array;
		var fluxLineArr:Array;
		var rolloffLineArr:Array;
		
		var colorChange:ColorTransform;
		

		var xCoord:uint = 0;
		var val:Number;
		
		// Game stuff
		var enemies:Array = new Array();
		var scenery:Array = new Array();
		var sprite_x:Number;
		var sprite_y:Number;
		var prev_date:Date;
		var cur_date:Date;

		// Panda!
		var player:Player;
		var playerHitBox:Shape;
		
		// Bullet!
		var b:Bullet;
		var bullets:Array = new Array();
		var txtBullets;
		
		// Powerups!
		const MACHINE_GUN = 1;
		const HEART = 2;
		const PIERCE = 3;
		const MULTI = 4;
		const SPREAD = 5;
		
		var powerUps:Array = new Array();
		
		// Background
		var nearerBG_1:NearerBG;
		var nearerBG_2:NearerBG;
		var ground:MovieClip;
		var ground2:MovieClip;
		var mountains:MovieClip;
		var mountains2:MovieClip;
		
		// Utilities
		var i:uint = 0;
		var j:uint = 0;
		var count:uint = 0;
		var preludeFrameCount:uint = 1;
		var frameCount:uint = 1;
		var calcFrameCount:int = -1;
		var alfCount:Number = 1;
		var offset:uint = 2;
		var onStage = false;
		
		// Text boxes
		var txtIntensity;
		var txtHiInt;
		var txtLoInt;
		var txtAvgInt;
		var txtBrightness;
		var txtFlux;
		var txtHiFlux;
		var txtLoFlux;
		var txtAvgFlux;
		var txtMinFlux;
		var txtBandwidth;
		var txtHarmonics;
		var txtRolloff;
		var txtLineArraySize;
		var txtBox;
		
		var minFlux = null;
		var fluxTotal:Number = 0;
		var fluxNorm:int = 0;
		
		var harmFreq:Array;
		var harmAmp:Array;
		var pitch:int = 6;
		
		var harmonics:Number;
		var brightness:Number;
		var bandwidth:Number;
		var rolloff:Number;
		var rolloffVal:int;
		var fluxVal:int;
		
		var startedAt:Date;
		
		var h;
		var ymax:Number;
		
		var instructions:Instructions;
		
		var str:String;
		function vgText(text:String, fontSize:uint = MEDIUM, xpos = 0, ypos = 0):Sprite {
			var myFontMap;
			var letter_width:uint;
			var letter_height:uint;
			
			if (fontSize == MEDIUM) {
				myFontMap = fontMapMedium; 
				letter_width = MEDIUM_LW;
				letter_height = MEDIUM_LH;
			} else if (fontSize == LARGE) {
				myFontMap = fontMap;
				letter_width = LETTER_WIDTH;
				letter_height = LETTER_HEIGHT;
			} else if (fontSize == SMALL) {
				myFontMap = fontMapSmall;
				letter_width = SMALL_LW;
				letter_height = SMALL_LH;
			} else {
				myFontMap = fontMapTiny;
				letter_width = TINY_LW;
				letter_height = TINY_LH;
			}
			
			text = text.toUpperCase();
			var textSprite:Sprite = new Sprite();
			var letter:BitmapData;
			var letterRect:Rectangle;
			var offsetFromA:int;
			var row_offset:int;
			var pt = new Point(0, 0);
			var letterBitmap:Bitmap;
			for (var i = 0; i < text.length; i++) {
				if (text.charAt(i) == '!') {
					offsetFromA = 28;   // ugly, but bitmap has its own character order
				} else if (text.charAt(i) == '%') {
					offsetFromA = 31;
				} else if (!isNaN(parseInt(text.charAt(i)))){
					offsetFromA = parseInt(text.charAt(i)) - 11;  // also gross
				} else {
					offsetFromA = text.charCodeAt(i) - "A".charCodeAt();
				}
				row_offset = (offsetFromA + A_POS_X) / FONT_BITMAP_WIDTH
				letterRect = new Rectangle(letter_width * ((A_POS_X + offsetFromA) % FONT_BITMAP_WIDTH), 
										   letter_height * (A_POS_Y + row_offset), letter_width, letter_height);
				letter = new BitmapData(letter_width, letter_height, true, 0x000000);
				letter.copyPixels(myFontMap, letterRect, pt, null, null, true);
				letterBitmap = new Bitmap(letter);
				letterBitmap.x = letter_width * i;
				textSprite.addChild(letterBitmap);
			}
			textSprite.x = xpos;
			textSprite.y = ypos;
			return textSprite;
		}
		
		var rawSound:Sound;
		public function rawSoundLoaded(event:Event) {
			songLength = rawSound.length;
			rawSound = null;
		}
		
		var mp3filename:String;
		var startTime:int;
		public function gameAudioStuff(filename, x_coord, y_coord){
			game_over = false;
			
			startTime = (new Date()).getTime();
			
			instructions = new Instructions();
			instructions.x = SW;
			instructions.y = 100;
			instructions.vx = -2;
			instructions.vy = 0;
			addChild(instructions);
			
			mp3filename = filename;
			songLoaded = false;
			introMusicChannel = introMusic.play();
			
			sprite_x = int(x_coord);
			sprite_y = int(y_coord);

			// Define audio file, use this example file or specify the path (local or server) of your own file
			str = filename;
			
			addEventListener(Event.ENTER_FRAME, onPreludeFrame);
			
			
			this.addEventListener(Event.ADDED_TO_STAGE, addedToStage);
			
			// Add farthest moving background
			nearerBG_1 = new NearerBG();
			nearerBG_2 = new NearerBG();
			nearerBG_1.x = 0;
			nearerBG_1.y = 4.5;
			nearerBG_2.x = SW;
			nearerBG_2.y = nearerBG_1.y;
			addChild(nearerBG_1);
			addChild(nearerBG_2);
			
			SCORE_LABEL.x = 195;
			SCORE_LABEL.y = 10;
			addChild(SCORE_LABEL);
			addChild(scoreSprite);
			
			LIFE_LABEL.x = 10;
			LIFE_LABEL.y = 10;
			addChild(LIFE_LABEL);
			addChild(lifeSprite);
			INSTR_1.visible = false;
			INSTR_2.visible = false;
			POWER_UP_MESSAGE.visible = false;
			PUM2.visible = false;
			addChild(INSTR_1);
			addChild(INSTR_2);
			addChild(POWER_UP_MESSAGE);
			addChild(PUM2);
			
			loadSprite.y = 150;
			addChild(loadSprite);
		
			// Initialize objects for drawing
			lineArr = new Array();
			line = new MovieClip();
			lineArr.push(line);
			line.graphics.lineStyle( 1, 0xFF0000, 1000);
			line.graphics.moveTo(0, 400);
			addChild(line);
			
			fluxLineArr = new Array();
			fluxLine = new MovieClip();
			fluxLineArr.push(fluxLine);
			fluxLine.graphics.lineStyle( 1, 0x0000FF, 1000);
			fluxLine.graphics.moveTo(0, 400);
			addChild(fluxLine);
			
			rolloffLineArr = new Array();
			rolloffLine = new MovieClip();
			rolloffLineArr.push(rolloffLine);
			rolloffLine.graphics.lineStyle( 1, 0x00FF00, 1000);
			rolloffLine.graphics.moveTo(0, 400);
			addChild(rolloffLine);
			
			ground = new Ground();
			ground.x = 0;
			ground.y = 500;
			
			
			ground2 = new Ground();
			ground2.x = 1600;
			ground2.y = 500;
			
			
			mountains = new Mountains();
			mountains.x = 0;
			mountains.y = 500 - ground.height - mountains.height + 80;
			addChild(mountains);
			
			mountains2 = new Mountains();
			mountains2.x = 1600;
			mountains2.y = 500 - ground.height - mountains.height + 80;
			addChild(mountains2);
			
			// So the ground appears in front
			addChild(ground);
			addChild(ground2);
			
			enemies = new Array();
			prev_date = new Date();
			
			Mouse.hide();
			addPlayer();
			
			
			currentGroundSpeed = 1;
			addEventListener(MouseEvent.MOUSE_DOWN, mouseClick);
			addEventListener(MouseEvent.MOUSE_UP, mouseLift);
		}
		
		public function initALF(event:Event) {
			// Create ALF object
			myALF = new ALF(str, 0, FPS, true, LOOKAHEAD);
			
			myALF.addEventListener(myALF.PROG_EVENT, loadProgress);
			myALF.addEventListener(myALF.FILE_LOADED, audioLoaded, false, 0, true);     // Adds listener for when the audio data has loaded
			myALF.addEventListener(myALF.FILE_COMPLETE, audioFinished, false, 0, true); // Event for when the file has fiished playing
		}
		
		var video_duration:Number;
		function onPreludeFrame(event:Event) {
			if (MovieClip(parent).video_duration) {
				video_duration = MovieClip(parent).video_duration;
				var current_time:int = (new Date()).getTime();
			}
			
			if (!player.spaceKeyDown && player.mouseDown && player.machineGun && preludeFrameCount % 2 == 0) {
				playerShoot();
			}
			
			POWER_UP_MESSAGE.y = 100;
			POWER_UP_MESSAGE.x = (800 - POWER_UP_MESSAGE.width) / 2;
			PUM2.y = 120;
			PUM2.x = (800 - PUM2.width) / 2;
			if (preludeFrameCount % FPS == 0) {
				POWER_UP_MESSAGE.visible = PUM2.visible = !POWER_UP_MESSAGE.visible;
			}
			
			removeChild(loadSprite);
			loadSprite = vgText(pctLoaded, LARGE, SW / 2 - LETTER_WIDTH * 3 / 2, 150);
			addChild(loadSprite);
			setChildIndex(loadSprite, getChildIndex(player) - 1);
			
			
			
			movePlayer();
			movePowerUps();
			moveBackground();
			moveBadGuys();
			moveBullets();
			moveInstructions();
			
			if (Math.random() * 100 < 1) {
				addBlueDisc();
			}
			
			// Game Over?
			if (player && player.dead) {
				parent.removeEventListener(KeyboardEvent.KEY_DOWN, keyPress)
				removeEventListener(MouseEvent.MOUSE_DOWN, mouseClick);
				removeEventListener(MouseEvent.MOUSE_UP, mouseLift);
				myALF.loadNewSong("fake.mp3", 0);
			}

			if(introMusicChannel.soundTransform.volume <= 0) {
				POWER_UP_MESSAGE.visible = false;
				PUM2.visible = false;
				removeChild(loadSprite); 
				
				removeEventListener(Event.ENTER_FRAME, onPreludeFrame);
				myALF.addEventListener(myALF.NEW_FRAME, onFrame, false, 0, true);
				
				addBoss();
				
				startedAt = new Date();
				myALF.startAudio();
				//trace('playing audio ...');	
			} else if (songLoaded) {
				introMusicVolControl = introMusicChannel.soundTransform;
				introMusicVolControl.volume -= 0.005;
				introMusicChannel.soundTransform = introMusicVolControl;
			}
			preludeFrameCount++;
		}
		
		function movePlayer():void {
			if (mouseX > 5 && player) { 
				if (mouseY > SH - 90) {
					if(player.y <= SH - 90) {
						player.gotoAndPlay('run');
					}
				} else if (mouseX < player.x) {
					player.gotoAndPlay('fly_back');
					player.stopcount = FPS / 2;
				} else if (mouseX > player.x) {
					player.gotoAndPlay('fly_forward');
				} else { // mouseX == player.x
					if (player.stopcount > 0) {
						player.stopcount--;
					} else if (player.stopcount == 0) {
						player.stopcount--;
						player.gotoAndPlay('fly_forward');
					}
				}
				player.x = mouseX; 
			}
			if (mouseY > 5 && player) { player.y = mouseY; }
			
			if (player) {
				if (player.shakeCount > 0) {
					player.shakeCount--;
					player.x += Math.random() * 20 - 10;
					if (player.x < 5) { player.x = 5; }
					player.y += Math.random() * 20 - 10;
					if (player.y < 5) { player.x = 5; }
					if (player.shakeCount > FPS / 2) {
						// There doesn't seem to be a way to retroactively apply this effect to the "current" frame
						// since that frame has already been processed.  I reduced the lookahead so the offset from
						// when the hit 'sound' is processed isn't as far off from the shake animation.
						if (frameCount > 1) {  // Make sure we don't try to use vocoder before song is loaded
							myALF.vocoder(true, Math.random() * 1.5 + 0.5, 1.0);
						}
					}
				}
				playerHitBox.x = player.x - PLAYER_HIT_WIDTH + 15;
				playerHitBox.y = player.y - (PLAYER_HIT_HEIGHT / 2) + 10;
			}
		}
		
		function moveBackground() {
			if (nearerBG_1.x <= -SW) {
				nearerBG_1.x = 0;
				nearerBG_2.x = SW;
			}
			nearerBG_1.x -= 0.25;
			nearerBG_2.x -= 0.25;
			
			if (ground.x <= -1599) {
				ground.x = 0;
			} else {
				if (currentGroundSpeed < GROUND_SPEED) {
					currentGroundSpeed += GROUND_SPEED / (10 * FPS);
				} else {
					currentGroundSpeed = GROUND_SPEED;
				}
				ground.x -= currentGroundSpeed;
			}
			
			if (ground2.x <= 1) {
				ground2.x = 1600;
			} else {
				ground2.x -= currentGroundSpeed;
			}
			
			if (mountains.x <= -1600) {
				mountains.x = 0;
			} else {
				mountains.x -= 1;
			}
			
			if (mountains2.x <= 0) {
				mountains2.x = 1600;
			} else {
				mountains2.x -= 1;
			}
		}
		
		function addPlayer() {
			player = new Player();
			player.x = 200;
			player.y = 200;
			player.gunType = MULTI;
			player.gunLevel = 1;
			player.pierce = 1;
			player.machineGun = false;
			player.shakeCount = 0;
			player.life = PLAYER_MAX_LIFE;
			player.score = 0;
			player.dead = false;
			player.got_hit = false;
			
			playerHitBox = new Shape();
			
			// Uncomment this to make the hitbox visible
			//playerHitBox.graphics.beginFill(0xFF0000);
			playerHitBox.graphics.drawRect(0, 0, PLAYER_HIT_WIDTH, PLAYER_HIT_HEIGHT);
			
			addChild(player);
			addChild(playerHitBox);
			
		}
		
		function playerShoot():void {
			if(player && player.life > 0 && !game_over) {
				playerShootSound.play();
				bullets.push(new Bullet());
				bullets[bullets.length - 1].x = player.x + player.width / 2;
				bullets[bullets.length - 1].y = player.y + 17;
				bullets[bullets.length - 1].vx = 20;
				bullets[bullets.length - 1].vy = 0;
				bullets[bullets.length - 1].ax = 0;
				bullets[bullets.length - 1].ay = 0;
				bullets[bullets.length - 1].hp = player.pierce;
				
				addChild(bullets[bullets.length - 1]);
				
				if (player.gunLevel > 1) {
					var bullet2 = new Bullet();
					
					switch (player.gunType) {
						case MULTI:
							bullet2.x = player.x + player.width / 2;
							bullet2.y = player.y + 23;
							bullet2.vx = 20;
							bullet2.vy = 0;
							bullet2.ax = 0;
							bullet2.ay = 0;
							bullet2.hp = player.pierce;
							break;
						case SPREAD:
							bullet2.x = player.x + player.width / 2;
							bullet2.y = player.y + 18;
							bullet2.vx = 20;
							bullet2.vy = 5;
							bullet2.ax = 0;
							bullet2.ay = 0;
							bullet2.hp = player.pierce;
							break;
					}
					bullets.push(bullet2);
					addChild(bullet2);
				}
				
				if (player.gunLevel > 2) {
					var bullet3 = new Bullet();
					
					switch (player.gunType) {
						case MULTI:
							bullet3.x = player.x + player.width / 2;
							bullet3.y = player.y + 10;
							bullet3.vx = 20;
							bullet3.vy = 0;
							bullet3.ax = 0;
							bullet3.ay = 0;
							bullet3.hp = player.pierce;
							break;
						case SPREAD:
							bullet3.x = player.x + player.width / 2;
							bullet3.y = player.y + 16;
							bullet3.vx = 20;
							bullet3.vy = -5;
							bullet3.ax = 0;
							bullet3.ay = 0;
							bullet3.hp = player.pierce;
							break;
					}
					bullets.push(bullet3);
					addChild(bullet3);
				}
			}
		}
		
		function mouseClick(mouseEvent:MouseEvent) {
			if (!player.machineGun && !player.spaceKeyDown) {
				// Only fire here if the player does NOT have the machine gun
				// Otherwise firing is taken care of in onFrame()
				// We don't want people to click repeatedly with machine gun to get extra shots
				// (i.e. one on the click itself and then another one in onFrame())
				playerShoot();
			}
			player.mouseDown = true;			
		}
		
		function mouseLift(mouseEvent:MouseEvent) {
			player.mouseDown = false;
		}
		
		public function keyPress(keyboardEvent:KeyboardEvent) {
			if (keyboardEvent.keyCode == Keyboard.SPACE) {
				if (player.machineGun || !player.spaceKeyDown) {
					playerShoot();
				}
				player.spaceKeyDown = true;
			}
		}
		
		public function keyLift(keyboardEvent:KeyboardEvent) {
			if (keyboardEvent.keyCode == Keyboard.SPACE) {
				player.spaceKeyDown = false;
			}
		}
		
		function moveBullets() {
			for(var bul = 0; bul < bullets.length; bul++) {
				bullets[bul].vx += bullets[bul].ax;
				bullets[bul].vy += bullets[bul].ay;
				bullets[bul].x += bullets[bul].vx;
				bullets[bul].y += bullets[bul].vy;
				if (bullets[bul].x > SW + 20 || bullets[bul].y > 510) {
					removeChild(bullets[bul]);
					bullets[bul] = null;
				}
			}
			bullets = bullets.filter(noNull);
		}
		
		function moveInstructions() {
			if (instructions) {
				instructions.x += instructions.vx;
				instructions.y += instructions.vy;
				if (instructions.x < -instructions.width) {
					removeChild(instructions);
					instructions = null;
				}
			}
		}
		
		function movePowerUps() {
			for(var pow = 0; pow < powerUps.length; pow++) {
				
				powerUps[pow].x += powerUps[pow].vx;
				powerUps[pow].y += powerUps[pow].vy;
				if (powerUps[pow].x < -50 ||
					powerUps[pow].x > 850 ||
					powerUps[pow].y < -50 ||
					powerUps[pow].y > 650) {
					removeChild(powerUps[pow]);
					powerUps[pow] = null;
				} else {
					checkForCollect(pow);
				}
			}
			powerUps = powerUps.filter(noNull);
		}
		
		function checkForCollect(pow:uint):void {
			if (powerUps[pow].hitTestObject(playerHitBox)) {
				powerUpCollectSound.play();

				switch (powerUps[pow].flavor) {
					case MACHINE_GUN:
						player.machineGun = true;
						break;
					case HEART:
						player.life += 10;
						updateLife();
						break;
					case PIERCE:
						player.pierce++;
						break;
					case MULTI:
						if (player.gunType == MULTI && player.gunLevel < 3) {
							player.gunLevel++;
						}
						player.gunType = MULTI;
						
						break;
					case SPREAD:
						if (player.gunType == SPREAD && player.gunLevel < 3) {
							player.gunLevel++;
						} 
						player.gunType = SPREAD;
						break;
				}
				removeChild(powerUps[pow]);
				powerUps[pow] = null;
			}
		}
		
		function addScenery() {
			var t:MovieClip;
			switch (Math.floor(Math.random() * 6)) {
				case 0:
					t = new Television();
					break;
				case 1:
					t = new Rocks1();
					break;
				case 2:
					t = new Rocks2();
					break;
				case 3:
					t = new Rocks3();
					break;
				case 4:
					t = new Rocks4();
					break;
				case 5:
				default:
					t = new tvFire();
					break;
			}
			
			t.x = SW;
			//t.y = Math.random() * 50 + (510 - ground.height);
			t.y = SH;
			t.vx = GROUND_SPEED;
			t.vy = 0;
			scenery.push(t);
			addChild(t);
		}
		
		function addGreenDisc() {
			h = new GreenDisc();
			h.flavor = GREEN_DISC;
			h.score = 100;
			h.x = 800;
			h.y = pitch * 12.5;
			h.maxY = pitch * 50 + 10;
			h.hp = 1;
			
			h.vx = -30;
			h.vy = 0;
			
			enemies.push(h);
			addChild(h);
		}
		
		function addRedDisc() {
			var r = new RedDisc();
			r.flavor = RED_DISC;
			r.score = 500;
			r.x = 800;
			r.y = Math.random() > 0.5 ? 0 : 500;
			r.hp = 10;
			
			// x^2 + y^2 = z^2
			r.vx = Math.random() * - 30.0 + 10;
			r.vy = (mouseY - r.y) / Math.abs((r.x - mouseX) / r.vx);
			
			
			enemies.push(r);
			addChild(r);
		}
		
		function addBlueDisc() {
			h = new BlueDisc();
			h.flavor = BLUE_DISC;
			h.score = 250;
			h.x = 800;
			h.y = pitch * 50;
			h.baseline_y = h.y;
			h.peak = 40
			h.hp = 1;
				
			h.vx = -5;
			h.vy = -10;
			
			enemies.push(h);
			addChild(h);
		}
		
		/////////// Popup Disc stuff ////////////
		var currentPopupSeq:uint = 1;
		
		function addPopup() {
			var p = new BlueDisc();
			p.flavor = POPUP;
			p.hp = 5;
			p.score = 200;
			p.x = (SW - 50) / 4 * currentPopupSeq;
			p.y = SH;
			//p.seq = currentPopupSeq;
			//p.seqMax = 4;
			p.vx = 0;
			p.vy = -60;
			p.ax = 0;
			p.ay = 5;
			
			
			enemies.push(p);
			addChild(p);
		}
		
		
		////////// Zig Zag disc stuff.  This is more complex because they have to act in unison. ///////////////
		var global_zig_pattern_pos:int = 0;
		var global_zig_pattern = [LEFT, UP, LEFT, DOWN];
		var global_zig_max_move = 60;
		var global_zig_state = MOVE;
		var global_zig_move_x = 20;
		var global_zig_move_y = 20;
		var global_zig_vx = -global_zig_move_x;
		var global_zig_vy = 0;
		var global_zig_traveled:int = 0;
		var global_zig_shake_x:int;
		var global_zig_shake_y:int;
		
		public function adjustZigState() {
			switch(global_zig_state) {
				case MOVE:
					global_zig_traveled += Math.abs(global_zig_vx) + Math.abs(global_zig_vy);
					if (global_zig_traveled >= global_zig_max_move) {
						global_zig_traveled = 0;
						global_zig_pattern_pos = nextPos(global_zig_pattern_pos, global_zig_pattern);
						global_zig_vx = -global_zig_move_x * global_zig_pattern[global_zig_pattern_pos].x;
						global_zig_vy = -global_zig_move_y * global_zig_pattern[global_zig_pattern_pos].y;
						global_zig_state = SHAKE;
					}
					break;
				case SHAKE:
					global_zig_shake_x = Math.random() * 4 - 2;
					global_zig_shake_y = Math.random() * 4 - 2;
					if (isPeak(FLUX_VAL, 2) && ALFframeBuffer[current_frame_num + 2][FLUX_VAL] > BEAT_FLUX) {
						global_zig_state = MOVE;
					}
					break;
			}
		}
		
		function addZigZag() {
			var z = new RedDisc();
			z.flavor = ZIG_ZAG;
			z.score = 50;
			z.x = 800;
			z.y = pitch * 12.5;
			z.hp = 10;
			//z.pattern = [LEFT, UP, LEFT, DOWN];
			//z.max_move = 60;
			//z.traveled = 0;
			//z.pattern_pos = 0;
			//z.state = MOVE;
			//z.move_x = 20;
			//z.move_y = 20;
			//z.vx = -z.move_x;
			//z.vy = 0;
			z.move = function() {
				switch(global_zig_state) {
					case MOVE:
						this.x += global_zig_vx;
						this.y += global_zig_vy;
						//this.traveled += Math.abs(this.vx) + Math.abs(this.vy);
/*						if (this.traveled >= this.max_move) {
							this.traveled = 0;
							this.pattern_pos = nextPos(this.pattern_pos, this.pattern);
							this.vx = -z.move_x * this.pattern[zig_pos].x;
							this.vy = -z.move_y * this.pattern[zig_pos].y;
							this.state = SHAKE;
						}*/
						break;
					case SHAKE:
						this.x += global_zig_shake_x;
						this.y += global_zig_shake_y;
/*						if (nowOnBeat) {
							this.state = MOVE;
						}*/
						break;
				}
			}
			
			
			
			enemies.push(z);
			addChild(z);
		}
		/////////////// End of Zig Zag stuff /////////////////////
		
		
		////////////// BOSS STUFF //////////////
		var boss:watermelonBoss;
		const HIDE = 0;
		const PEEK = 1;
		const PEEK_ATTACK = 2;
		const WITHDRAW = 3;
		const ATTACK = 4;
		const WAIT = 5;
		const DIE = 6;
		var bossHitBox:Shape = new Shape();
		var bossBodyCircle:Shape = new Shape();
		function addBoss():void {
			boss = new watermelonBoss();
			boss.dead = false;
			boss.x = 1000;	// off screen and out of bullet range
			boss.y = SH / 2.0;
			boss.vx = -1;
			boss.vy = 0.0;
			boss.k = 0.0025;
			boss.ax = 0;
			boss.baseline_y = boss.y;
			//boss.ay = boss.k * (boss.baseline_y - boss.y);
			boss.ay = 0;
			boss.phase = HIDE;
			boss.peekDistance = boss.width / 2;
			boss.attackFrame = (songLength / 1000) * 0.5 * FPS;	// enter 1/2 of the way through the song
			//boss.attackFrame = 11;
			//boss.attackFrame = 500;
			boss.cooldown = 0;
			boss.hit_cooldown = 0;
			boss.shot_cooldown = 0;
			boss.attack_type = -1;
			boss.ammo = 0;
			boss.seed_bullets = new Array();
			boss.score = 1000000;
			// Uncomment this to see the hitbox
			//bossHitBox.graphics.beginFill(0x00FF00);
			bossHitBox.graphics.drawRect(0, 0, 27, 45);
			bossHitBox.x = boss.x + 38;
			bossHitBox.y = boss.y - 81;
			
			bossBodyCircle.graphics.beginFill(0xFF0000);
			bossBodyCircle.graphics.drawEllipse(0, 0, 300, 350);
			bossBodyCircle.x = boss.x + 52;
			bossBodyCircle.y = boss.y - boss.height / 2 + 10;
			bossBodyCircle.visible = false;
			// Why is the circle becoming kind of dislodged
			// -- it's not, it's at a different spot relative to one frame of boss (hit frame)
			
			boss.attackFlux = BEAT_FLUX;
			boss.attack_cooldown = 0;
			addChild(bossHitBox);
			addChild(bossBodyCircle);
			boss.hp = 1000;
			
			boss.move = function():void {
				
				this.vx += this.ax;
				this.vy += this.ay;
				
				if (frameCount % (3 * FPS) == 0) {
					// Shall we change direction?
					boss.baseline_y += (Math.random() * 80 - 40);
					//boss.vx += Math.random() * 10 - 5;
				}
				if (boss.baseline_y < 0) { boss.baseline_y = 0; }
				if (boss.baseline_y > SH) { boss.baseline_y = SH; }
				if (boss.phase == ATTACK) {  // don't leave the screen
					if (boss.x < SW / 2 && boss.vx <= 0) { boss.vx *= -1 };
					if (boss.x > SW - boss.width && boss.vx >= 0) { boss.vx *= -1 };
				}
				
				this.x += this.vx;
				this.y += this.vy;
				
				bossHitBox.x += this.vx;
				bossHitBox.y += this.vy;
				//bossBodyCircle.x += this.vx;
				//bossBodyCircle.y += this.vy;
				bossBodyCircle.x = this.x + 52;
				bossBodyCircle.y = this.y - this.height / 2 + 10;
				
				if (boss.ammo > 0) {
					boss.shoot();
				}
			}
				
			boss.moveHere = function(x:int, y:int):void {
				this.x = x;
				this.y = y;
				bossHitBox.x = this.x + 38;
				bossHitBox.y = this.y - 81;
				bossBodyCircle.x = this.x + 52;
				bossBodyCircle.y = this.y - this.height / 2 + 10;
			}
				
			boss.start_attack = function():void {
				this.seed_bullets = new Array();
				switch (this.attack_type) {
					case 0:		// five bullets aimed right at the player, fired consecutively
						this.ammo = 5;
						this.cooldown = 1 * FPS;
						break;
						
					default:
						this.ammo = 10;
						this.cooldown = 1 * FPS;
						break;
				}
			}
			
			boss.shoot = function():void {
				var seed_bullet:SeedBullet;
				var seed_velocity = 20;
				var hyp:int;
				var dx:int;
				var dy:int;
				switch (this.attack_type) {
					case 0:		// five bullets aimed right at the player, fired consecutively
						if (current_flux > this.attackFlux && isPeak(FLUX_VAL) && this.shot_cooldown <= 0) {
							this.gotoAndStop('attack');
							seed_bullet = new SeedBullet();
							seed_bullet.ax = 0;
							seed_bullet.ay = 0;
							dx = this.x - mouseX;
							dy = this.y - mouseY;
							hyp = Math.sqrt(dx * dx + dy * dy);
							seed_bullet.vx = -seed_velocity * (dx / hyp);
							seed_bullet.vy = -seed_velocity * (dy / hyp);
							
							seed_bullet.flavor = SEED_BULLET;
							seed_bullet.x = this.x;
							seed_bullet.y = this.y;
							seed_bullet.hp = 9999;
							
							enemies.push(seed_bullet);
							addChild(seed_bullet);
							this.ammo -= 1;
							this.cooldown = 1 * FPS;
							this.shot_cooldown = Math.floor(FPS / 4.0);
						}
						break;
						
					default:	// simple spread shot fired all at once
						if (this.cooldown % FPS == 0 && this.shot_cooldown == 0) {
							boss.gotoAndStop('attack');
							for (var i:int = 0; i < 5; i++) {
								seed_bullet = new SeedBullet();
								seed_bullet.ax = 0;
								seed_bullet.ay = 0;
								seed_bullet.vx = Math.cos(Math.PI / 6 * (2 - i)) * -seed_velocity;
								seed_bullet.vy = Math.sin(Math.PI / 6 * (2 - i)) * -seed_velocity;
								seed_bullet.x = boss.x;
								seed_bullet.y = boss.y;
								seed_bullet.flavor = SEED_BULLET;
								seed_bullet.hp = 9999;
								enemies.push(seed_bullet);
								addChild(seed_bullet);
							}
							this.ammo -= 5;
							this.shot_cooldown = FPS / 2.0;
							this.cooldown = 1 * FPS;
						}
						break;
				}
			}	
				
			addChild(boss);
		}
		
		function boringScreen():Boolean { // is not much happening?
			return enemies.length <= 10;
		}
		
		function checkForBossHits():void {
			for (var i:int = 0; i < bullets.length && boss.hp > 0; i++) {
				if (bossHitBox.hitTestPoint(bullets[i].x, bullets[i].y, false)) {
					boss.hp -= bullets[i].hp;
					if (boss.hp <= 0) {
						bossDie();
					} else {
						boss.hit_cooldown = 0.5 * FPS;
						bossHitSound.play();
						boss.gotoAndStop('hit');
						boss.moveHere(boss.x + 2 * bullets[i].hp, boss.y);
						
						
						// Constant (flat) knockback
						//boss.moveHere(boss.x + 5, boss.y);
						//boss.moveHere(boss.x + 1, boss.y);
					}
					removeChild(bullets[i]);
					bullets[i] = null;						
				} else {
					if (bossBodyCircle.hitTestPoint(bullets[i].x, bullets[i].y, true)) {
						bullets[i].vx = -2;
						bullets[i].ay = 2;
					}
				}
			}
			bullets = bullets.filter(noNull);
		}
		
		function bossDie():void {
			removeChild(bossHitBox);
			player.score += boss.score;
			removeChild(scoreSprite);
			scoreSprite = vgText(padZeros(player.score, 7), MEDIUM, 200 + SCORE_LABEL.width, 10);
			addChild(scoreSprite);
			boss.ay = 0.25;
			boss.vy = -10;
			boss.phase = DIE;
			boss.dead = true;
		}
		
		function moveBoss():void {
			checkForBossHits();
			if (frameCount > 10 * FPS) {  // Don't even think about moving until at least 10 seconds in
				switch (boss.phase) {
					case HIDE:
						if (frameCount > boss.attackFrame) {
						//if (frameCount > 11 * FPS) {
							boss.moveHere(SW, SH / 2 + 100);
							//boss.vy = -5;
							boss.phase = ATTACK;
						} else if (boss.cooldown == 0) {
							if (Math.random() * 100 <= 1 || boringScreen()) {
								boss.vx = -2;
								boss.vy = 0;
								
								boss.moveHere(SW, Math.random() * 400 + 100);
								boss.peek_timeout = 5 * FPS;
								boss.phase = PEEK;
							}
						} else {
							boss.cooldown--;
						}	
						break;
					case PEEK:
						if (boss.peek_timeout > 0) { boss.peek_timeout--; }
						if (boss.hit_cooldown <= 0) {
							boss.gotoAndStop('normal');
						} else {
							boss.gotoAndStop('hit');
						}
						if (boss.x <= SW - boss.peekDistance || boss.peek_timeout <= 0) {
							boss.cooldown = 1 * FPS;
							boss.vx = 0;
							boss.vy = 0;
							boss.phase = PEEK_ATTACK;
						}
						break;
					case PEEK_ATTACK:
						if (boss.peek_attack_timeout > 0) { boss.peek_attack_timeout--; }
						if (boss.cooldown > 0) {
							boss.cooldown--;
						} else if (boss.attack_type < 0) {
							boss.attack_type = Math.floor(Math.random() * 100 % 2);
							boss.peek_attack_timeout = 5 * FPS;
							boss.start_attack();
						} else if (boss.ammo <= 0 || boss.peek_attack_timeout <= 0) {
							boss.attack_type = -1;
							boss.cooldown = 2 * FPS;
							boss.phase = WITHDRAW;
						}
						break;
					case WITHDRAW:
						if (boss.cooldown == 1 * FPS) {
							if (boss.hit_cooldown <= 0) {
								boss.gotoAndStop('normal');
							} else {
								boss.gotoAndStop('hit');
							}
						} else if (boss.cooldown <= 0) {
							if (boss.hit_cooldown <= 0) {
								boss.gotoAndStop('normal');
							} else {
								boss.gotoAndStop('hit');
							}
							boss.vx = 2;	// redundant to set this every time we go through, but meh
						}
						if (boss.x > SW) {
							boss.cooldown = 5 * FPS; // don't come out again for at least 5 seconds
							boss.moveHere(SW + 1000, boss.y); // make sure he's out of range						
							boss.phase = HIDE;
						}
						if (boss.cooldown > 0) { boss.cooldown--; }
						break;
					case ATTACK:
						if (boss.hit_cooldown <= 0 && boss.cooldown <= 0) {
							boss.gotoAndStop('normal');
						} else if (boss.cooldown <= 0) {
							boss.gotoAndStop('hit');
						}
						// Harmonic motion
						boss.ay = boss.k * (boss.baseline_y - boss.y);
						boss.vx += boss.ax;
						boss.vy += boss.ay;
						//boss.x += boss.vx;
						//boss.y += boss.vy;
						
						if (boss.attack_type < 0 && boss.attack_cooldown == 0 && boss.ammo <= 0) {
							boss.attack_type = Math.floor(Math.random() * 100 % 2);
							boss.start_attack();
						//} else if (boss.ammo > 0) {
							//boss.shoot();
						} else if (boss.ammo <= 0 && boss.attack_cooldown <= 0) {
							boss.attack_type = -1;
							boss.attack_cooldown = 2 * FPS;
						}
						if (boss.cooldown > 0) { boss.cooldown--; }
						break;
					case DIE:
						boss.gotoAndStop('dead');
						if (boss.y > SH + boss.height) {
							boss.visible = false;
							// should remove here?
						} else {
							if (frameCount % 2 == 0) {
								var e:Explosion = new Explosion();
								e.x = Math.random() * (boss.width - 80) + boss.x + 40;
								e.y = Math.random() * (boss.height - 80) + (boss.y / 2.0);
								addChild(e);
							}
						}
						break;
						
					default:
						// do nothing
						break;
				}
				if (boss.hit_cooldown > 0) { boss.hit_cooldown--; }
				if (boss.attack_cooldown > 0) { boss.attack_cooldown--; }
				if (boss.shot_cooldown > 0) { boss.shot_cooldown--; }
				boss.move();
				
			}
		}
		
		function moveBadGuys():void {
			adjustZigState();
			// Move enemies
			for (i = 0; i < enemies.length; i++) {
				checkForHits(i);
				
				h = enemies[i];
				if (h && h.x < -100) {
					killEnemy(i, false);  // Don't play kill sound when the enemy just moves off screen
					enemy_escaped = true;
				}
				
				if (h) {
					switch(h.flavor) {
						case GREEN_DISC:
							ymax = h.maxY;
							
							if(h.y <= ymax) {
								//h.x -= (701 - h.x) / 10;
								h.x += h.vx;
							}
							else if(h.y > 0) {
								h.y -= 50;
								//h.x -= ((700 - h.y) / 50 + 5);
								h.x -= 10;
							} else {
								killEnemy(i);
							}
							break;
							
						case RED_DISC:
							h.x += h.vx;
							h.y += h.vy;
							break;
							
						case BLUE_DISC:
							h.x += h.vx;
							h.y += h.vy;
							
							if (h.y < h.baseline_y - h.peak) {
								h.y = h.baseline_y - h.peak;
								h.vy = -h.vy;
							} else if (h.y > h.baseline_y + h.peak) {
								h.y = h.baseline_y + h.peak;
								h.vy = -h.vy;
							}
							break;
						case ZIG_ZAG:
							h.move();
							break;
						default:
							h.x += h.vx;
							h.y += h.vy;
							h.vx += h.ax;
							h.vy += h.ay;
							break;
					}
				}
			}
			enemies = enemies.filter(noNull);
		}
		
		function checkForHits(q) {
			if (enemies[q]) {
				for(j = 0; j < bullets.length; j++) {
					if (enemies[q] && bullets[j]) {
						if (enemies[q].hitTestPoint(bullets[j].x, bullets[j].y, false)) {
							
							
							var bulletstr = bullets[j].hp;
							bullets[j].hp -= enemies[q].hp;
							enemies[q].hp -= bulletstr;
							
							if (enemies[q].flavor == ZIG_ZAG) {
								if (enemies[q].hp < 10 && enemies[q].hp >= 8) {
									enemies[q].gotoAndStop(2);
								} else if (enemies[q].hp < 8 && enemies[q].hp >= 4) {
									enemies[q].gotoAndStop(3);
								} else if (enemies[q].hp < 4 && enemies[q].hp >= 1) {
									enemies[q].gotoAndStop(4);
								}
							}
							
							
							if (enemies[q].hp <= 0) {
								player.score += enemies[q].score;
								removeChild(scoreSprite);
								scoreSprite = vgText(padZeros(player.score, 7), MEDIUM, 200 + SCORE_LABEL.width, 10);
								addChild(scoreSprite);
								killEnemy(q);
							} else {
								discExplodeSound.play();
							}
							if (bullets[j].hp <= 0) {
								killBullet(j);
							}
						}
					}
				}
				bullets = bullets.filter(noNull);
				
				
				// Check if panda got hit!
				if (enemies[q]) {
					if (enemies[q].hitTestObject(playerHitBox)) {
						if (enemies[q].flavor != SEED_BULLET) {
							killEnemy(q);
						}
						hitPlayer();
					}
				}
			}
		}

		function killEnemy(q, playsound:Boolean = true):void {
			if (enemies[q]) {
				if (enemies[q].flavor == BLUE_DISC || (enemies[q].flavor == POPUP && Math.random() * 100 < 10)) {
					dropPowerup(enemies[q]);
				}
				
				if (enemies[q].flavor != SEED_BULLET) {
					enemies[q].gotoAndPlay(2);
				}
				if (playsound && enemies[q].flavor != SEED_BULLET) { discExplodeSound.play(); }
				
				if (enemies[q].flavor == SEED_BULLET) {
					removeChild(enemies[q]);
				}
				enemies[q] = null;
			}
		}
		
		function dropPowerup(enemy):void {
			var powerUp:MovieClip = null;
			var whatDidIGet:uint = Math.random() * 5 + 1;

			if (whatDidIGet > 0) {
				switch (whatDidIGet) {
					case MACHINE_GUN:
						// Machine Gun
						powerUp = new PwrMachinegun();
						powerUp.flavor = MACHINE_GUN;
						break;
					case HEART:
						powerUp = new PwrHealth();
						powerUp.flavor = HEART;
						break;
					case PIERCE:
						powerUp = new PwrPierce();
						powerUp.flavor = PIERCE;
						break;
					case MULTI:
						powerUp = new PwrMulti();
						powerUp.flavor = MULTI;
						break;
					case SPREAD:
						powerUp = new PwrSpread();
						powerUp.flavor = SPREAD;
						break;		
				}
				powerUp.x = enemy.x;
				powerUp.y = enemy.y;
				powerUp.vx = enemy.vx;
				if (powerUp.vx == 0) { powerUp.vx = -5; }
				powerUp.vy = 0;
				powerUps.push(powerUp);
				addChild(powerUp);
			}
		}
		
		function killBullet(j) {
			removeChild(bullets[j]);
			bullets[j] = null;
		}

		function updateLife() {
			removeChild(lifeSprite);
			lifeSprite = vgText(padZeros(player.life, 3), MEDIUM, 10 + LIFE_LABEL.width, 10);
			addChild(lifeSprite);
		}
		
		function hitPlayer():void {
			// Invincible while recovering from hit
			if (player.shakeCount == 0 && !INVINCIBLE) {
				player.got_hit = true;
				player.life -= 10;
				if (player.life <= 0) {
					player.dead = true;
				} else {
					updateLife();
				}
				player.shakeCount = 1 * FPS;
			}
		}

		// This handles the event that ALF dispatches for each audio frame. If your video frame rate is
		// the same, you should have synchronicity between your audio feature values and your video frames,
		// that is, there should be no lag or offset between the value calculated and the audio that is playing.
		public function onFrame(event:Event):void{			
			// Uncomment and adjust to speed up/slow down or change pitch
			//myALF.vocoder(true, 1.0, 2.0);
			
			nowOnBeat = onBeat();
			
			if (!player.spaceKeyDown && player.mouseDown && player.machineGun && frameCount % 2 == 0) {
				playerShoot();
			}
			
			movePlayer();
			movePowerUps();
			moveBackground();
			moveBadGuys();
			moveBoss();
			moveBullets();
			moveInstructions();

			// Move TVs
			for(var d:int = 0; d < scenery.length; d++) {
				scenery[d].x -= scenery[d].vx;
				scenery[d].y -= scenery[d].vy;
				if (scenery.x < scenery[d].width) {
					removeChild(scenery[d]);
					scenery[d] = null;
				}
			}
			scenery = scenery.filter(noNull);
			
			/*if (mouseX < 0) { player.x = 0; }
			else if (mouseX > stage.width) { player.x = stage.width; }
			else { player.x = mouseX; }*/
			
			/*if (mouseY < 0) { player.y = 0; }
			else if (mouseY > stage.height) { player.y = stage.height; }
			else { player.y = mouseY; }*/
			
			intensity = myALF.getIntensity() + adjustIntensity;
			flux = myALF.getFlux() * adjustFlux;
			// Not currently using any of these
			//brightness = myALF.getBrightness();
			//bandwidth = myALF.getBandwidth();
			//rolloff = myALF.getRolloff();
			
			
			
			if (frameCount > START_COUNT_SECONDS * FPS) {
				if (intensity > hiIntensity) hiIntensity = intensity;
				if (intensity < loIntensity) loIntensity = intensity;
				sumIntensity += intensity;
				avgIntensity = sumIntensity / (frameCount - (START_COUNT_SECONDS * FPS));
				
				if (flux > hiFlux) hiFlux = flux;
				if (flux < loFlux) loFlux = flux;
				sumFlux += flux;
				avgFlux = sumFlux / (frameCount - (START_COUNT_SECONDS * FPS));
			}
			
			if (frameCount == END_COUNT_SECONDS * FPS) {
				if (avgIntensity < TARGET_AVG_INTENSITY) adjustIntensity = TARGET_AVG_INTENSITY - avgIntensity;
				if (avgFlux < TARGET_AVG_FLUX) adjustFlux = TARGET_AVG_FLUX / avgFlux;
			}
			
			
			
			// Harmonics/Pitch detection
			myALF.getHarmonics(1);
			harmFreq = myALF.getHarmonicFrequencies();
			pitch = findPitch(harmFreq);
			//txtHarmonics = this.parent.getChildByName("txtHarmonics");
			//txtHarmonics.text = String(harmFreq[0]);

			

			cur_date = new Date();
			
			if (onStage == true) {
				//txtBox = this.parent.getChildByName("txtFrame");
//				txtBox.text = String(frameCount / FPS);
//				
//				txtLoInt = this.parent.getChildByName("txtLoInt");
//				txtLoInt.text = String(loIntensity);
//				
//				txtHiInt = this.parent.getChildByName("txtHiInt");
//				txtHiInt.text = String(hiIntensity);
//				
//				txtAvgInt = this.parent.getChildByName("txtAvgInt");
//				txtAvgInt.text = String(avgIntensity);
//				
//				txtBox = this.parent.getChildByName("txtLoFlux");
//				txtBox.text = String(loFlux);
//				
//				txtBox = this.parent.getChildByName("txtHiFlux");
//				txtBox.text = String(hiFlux);
//				
//				txtBox = this.parent.getChildByName("txtAvgFlux");
//				txtBox.text = String(avgFlux);
//				
//				txtIntensity = this.parent.getChildByName("txtIntensity");
//				txtIntensity.text = String(intensity);
//				
//				txtBrightness = this.parent.getChildByName("txtBrightness");
//				txtBrightness.text = String(brightness);
//				
//				txtFlux = this.parent.getChildByName("txtFlux");
//				txtFlux.text = String(flux);
//				
//				txtBullets = this.parent.getChildByName("txtBullets");
//				txtBullets.text = bullets.length;
				//txtHarmonics.text = String(int(harmFreq[0])) + " " + String(int(harmFreq[1]));
/*					
				if( (cur_date.valueOf() - startedAt.valueOf() >= 10000) && (fluxNorm == 0) && (minFlux < 40000)) {
					fluxNorm = (40000.0 / minFlux);
				}*/
				//flux *= 40000;
				
/*				txtBandwidth = this.parent.getChildByName("txtBandwidth");
				txtBandwidth.text = String(bandwidth);
				
				txtRolloff = this.parent.getChildByName("txtRolloff");
				txtRolloff.text = String(rolloff);
				
				txtLineArraySize = this.parent.getChildByName("txtLineArraySize");
				txtLineArraySize.text = String(lineArr.length);
				
				var txtMouseX = this.parent.getChildByName("txtMouseX");
				txtMouseX.text = mouseX;
				var txtMouseY = this.parent.getChildByName("txtMouseY");
				txtMouseY.text = mouseY;*/
			}

			// Clear screen if reached border
            if(xCoord > 550){

				for(i = 0; i < lineArr.length; i++){
					if (INTENSITY_LINE) {
						lineArr[i].graphics.clear();
						lineArr[i] = null;
					}
					
					if (FLUX_LINE) {
						fluxLineArr[i].graphics.clear();
						fluxLineArr[i] = null;
					}
					
					if (ROLLOFF_LINE) {
						rolloffLineArr[i].graphics.clear();
						rolloffLineArr[i] = null;
					}
					
				}
				
				if (INTENSITY_LINE) {
					lineArr.splice(0, lineArr.length);
					lineArr = new Array();
					line.graphics.moveTo(offset, 400);
				}
				
				if (FLUX_LINE) {
					fluxLineArr.splice(0, fluxLineArr.length);
					fluxLineArr = new Array();
					fluxLine.graphics.moveTo(offset, 400);
				}
				
				if (ROLLOFF_LINE) {
					rolloffLineArr.splice(0, fluxLineArr.length);
					rolloffLineArr = new Array();
					rolloffLine.graphics.moveTo(offset, 400);
				}
				
				xCoord = 0;
			}

			if(frameCount > offset){
				// Adjust values
				val = intensity/10;
				fluxVal = flux/1000;
				//rolloffVal = rolloff / 10;
				
				ALFframeBuffer.push([val, fluxVal, pitch]);
				
				// Draw lines
				if (FLUX_LINE) {
					if(isNaN(fluxVal)){ fluxVal = 0;}
					fluxLine.graphics.lineStyle( 1, 0x0000FF, 1000);
					fluxLine.graphics.lineTo(xCoord, 500 - fluxVal);
					addChild(fluxLine);
					fluxLine = new MovieClip();
					fluxLineArr.push(fluxLine);
					fluxLine.graphics.moveTo(xCoord, 500 - fluxVal);
				}
								
				if (ROLLOFF_LINE) {
					if(isNaN(rolloffVal)){ rolloffVal = 0;}
					rolloffLine.graphics.lineStyle( 1, 0x00FF00, 1000);
					rolloffLine.graphics.lineTo(xCoord, 800 - rolloffVal);
					addChild(rolloffLine);
					rolloffLine = new MovieClip();
					rolloffLineArr.push(rolloffLine);
					rolloffLine.graphics.moveTo(xCoord, 800 - rolloffVal);
				}
								
				if (INTENSITY_LINE) {
                    if(isNaN(val)){ val = 0;}
					line.graphics.lineStyle( 1, 0xFF0000, 1000);
					line.graphics.lineTo(xCoord, 1000 - val);
					addChild(line);
					line = new MovieClip();
					lineArr.push(line);
					line.graphics.moveTo(xCoord, 1000 - val);
				}
				
				
				//////////// ADD ENEMIES /////////////
				
				
				current_frame_num = ALFframeBuffer.length - LOOKAHEAD - 1;
				if (current_frame_num < 0) { current_frame_num = 0 };
				current_frame = ALFframeBuffer[current_frame_num];
				current_flux = current_frame[FLUX_VAL];
				current_intensity = current_frame[INTENSITY_VAL];
				current_pitch = current_frame[PITCH];
				
				// TUNE
				if (current_intensity > 60 && isPeak(INTENSITY_VAL, 0) && isPeak(FLUX_VAL)) {
					addGreenDisc();
				}
				
				// HI-FLUX ENEMIES
				if (current_flux > HI_FLUX) {
					//addGreenDisc();
					
					// HI-FLUX AND HI-INTENSITY
					if (current_intensity > HI_INTENSITY) {
						//addRedDisc();
					}
				}
				
				// ON THE BEAT
				if (current_flux > BEAT_FLUX  && isPeak(FLUX_VAL)) {
					addScenery();
					
					if (currentPopupSeq > 1) {
						addPopup();
						currentPopupSeq++;
						if (currentPopupSeq > 4) {
							currentPopupSeq = 1;
						}
					} else {					
						switch(Math.floor(Math.random() * 2)) {
							case 0:
								addZigZag();
								break;
							case 1:
								addPopup();
								currentPopupSeq++;
								break;
						}
					}
				}
				
				// HI-INTENSITY ENEMIES
				if (current_intensity > HI_INTENSITY) {
					//addGreenDisc();
				}
				
				//if (fluxVal > LO_FLUX && fluxVal < HI_FLUX / 4) {
				if (current_flux == 10 && Math.random() > ((frameCount < 10 * FPS) ? 0 : 0.75)) {
				//if (current_flux < 20 && current_flux >= 10 && isPeak(FLUX_VAL) && Math.random() > ((frameCount < 10 * FPS) ? 0 : 0.75)) {
					addBlueDisc();
				}
				
				
			}

			frameCount++;
			xCoord = xCoord + 3;
			
			// Game Over?
			if (player && player.dead) {
				parent.removeEventListener(KeyboardEvent.KEY_DOWN, keyPress)
				removeEventListener(MouseEvent.MOUSE_DOWN, mouseClick);
				removeEventListener(MouseEvent.MOUSE_UP, mouseLift);
				myALF.loadNewSong("fake.mp3", 0);
			}
/*				if (new Date().valueOf() - startedAt.valueOf() > 0) {
				if(calcFrameCount == -1) {
					calcFrameCount = frameCount - 1;
				}
				fluxTotal += flux;
			//} else if (frameCount == 100) {
				var avgFlux:Number = fluxTotal / (frameCount - calcFrameCount);
				txtMinFlux = this.parent.getChildByName("txtMinFlux");
				txtMinFlux.text = String(avgFlux);
			}*/
		}

		public function calculateBPM():void {
			
		}
		
		public function fadeoutIntro(event:Event):void {
		}

		public function loadProgress(progEvent:Event):void {
			//trace(progEvent.bytesLoaded + " / " + progEvent.bytesTotal);
			var pct = Math.floor(MP3_PORTION * 100 + progEvent.currentTarget.loadProgress * 100 * (1 - MP3_PORTION));
			pctLoaded = String(pct) + "%";	 
		}
		
		// This funciton is called when the audio has been loaded in ALF and the FILE_LOADED event has been dispatched
		public function audioLoaded(event:Event):void{
			var req:URLRequest = new URLRequest(mp3filename);
			rawSound = new Sound(req);
			rawSound.addEventListener(Event.COMPLETE, rawSoundLoaded);
			songLoaded = true;	
		}

		// This funciton is called when the audio has finished playing and the FILE_COMPLETE event has been dispatched
		public function audioFinished(event:Event):void{
			game_over = true;
			player.spaceKeyDown = false;
			//MovieClip(parent).removeEventListener(KeyboardEvent.KEY_DOWN, keyPress);
			//MovieClip(parent).removeEventListener(KeyboardEvent.KEY_UP, keyLift);
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPress);
			stage.removeEventListener(KeyboardEvent.KEY_UP, keyLift);
			removeEventListener(MouseEvent.MOUSE_DOWN, mouseClick);
			removeEventListener(MouseEvent.MOUSE_UP, mouseLift);
			player.mouseDown = false;
			player.spaceKeyDown = false;
			
			myALF.loadNewSong("fake.mp3", 0);
			
			for (var o:int = 0; o < enemies.length; o++) {
				if (enemies[o]) {
					if (enemies[o].flavor == SEED_BULLET) {
						removeChild(enemies[o]);
						enemies[o] = null;
					} else {
						killEnemy(o);
					}
				}
			}
			enemies = [];
			for (o = 0; o < bullets.length; o++) {
				if (bullets[o]) killBullet(o);
			}
			bullets = [];
			for (o = 0; o < powerUps.length; o++) {
				removeChild(powerUps[o]);
				powerUps[0] = null;
			}
			powerUps = [];
			for (o = 0; o < scenery.length; o++) {
				if (scenery[o]) {
					removeChild(scenery[o]);
					scenery[o] = null;
				}
			}
			scenery = [];
			removeChild(nearerBG_1);
			removeChild(nearerBG_2);
			removeChild(mountains);
			removeChild(mountains2);
			removeChild(ground);
			removeChild(ground2);
			removeChild(SCORE_LABEL);
			removeChild(scoreSprite);
			removeChild(LIFE_LABEL);
			removeChild(lifeSprite);
			removeChild(boss);
			if (instructions) {
				removeChild(instructions);
				instructions = null;
			}
			Mouse.show();
			removeChild(player);
			if (player.life >= 100 && !player.dead) {
				//MovieClip(parent).gotoAndStop(4);
				win();
			} else if (player.life > 0 && !player.dead) {
				//MovieClip(parent).gotoAndStop(3);
				win();
			} else {
				//win();
				MovieClip(parent).sky_bg.alpha = 0;
				ls = new LoseFull();
				ls.x = SW / 2;
				ls.y = ls.height / 2;
				ls.btnRetry.addEventListener(MouseEvent.CLICK, retry);
				scoreSprite = vgText(padZeros(player.score, 7), LARGE);
				scoreSprite.x = (SW / 2) - (scoreSprite.width / 2);
				scoreSprite.y = (SH / 2) - (scoreSprite.height / 2) - 9;
				addChild(scoreSprite);
				addChild(ls);
				setChildIndex(scoreSprite, numChildren - 1);
				ls.scoreBox.btn_fb.addEventListener(MouseEvent.CLICK, facebook);
			}
			

			//trace('audioFinished');
			//trace('---------------------------------------');
		}
		
		public function win():void {
			MovieClip(parent).sky_bg.alpha = 0;
			ws = new WinFull();
			ws.x = SW / 2;
			ws.y = ws.height / 2;
			ws.btnRetry.addEventListener(MouseEvent.CLICK, retry);
			
			if (player.got_hit == false) {
				player.score *= 2;
				ws.achievements_section.nohit_ach.gotoAndStop('on');
			}
			if (enemy_escaped == false && boss.dead == true) {
				player.score *= 2;
				ws.achievements_section.allkilled_ach.gotoAndStop('on');
			}
			
			scoreSprite = vgText(padZeros(player.score, 7), LARGE);
			scoreSprite.x = (SW / 2) - (scoreSprite.width / 2);
			scoreSprite.y = (SH / 2) - (scoreSprite.height / 2) - 9;
			addChild(scoreSprite);
			addChild(ws);
			setChildIndex(scoreSprite, numChildren - 1);
			ws.score_section.btn_fb.addEventListener(MouseEvent.CLICK, facebook);
		}
		
		public function retry(event:Event):void {
			removeChild(scoreSprite);
			if (ls) { removeChild(ls); }
			if (ws) { removeChild(ws); }
			MovieClip(parent).alf_demo = null;
			MovieClip(parent).titleSeq.visible = true;
			MovieClip(parent).startPanda();
			
		}
	
		public function addedToStage(event:Event):void {
			onStage = true;
		}
		
		
		// Lifted from Xmas game!
		public function facebook(evt:MouseEvent)
		{
			var w:MovieClip;
			if (player.got_hit == false && enemy_escaped == false && boss.dead == true) {
				w = new fbIconBoth();
			} else if (player.got_hit == false) {
				w = new fbIconNoDamage();
			} else if (enemy_escaped == false && boss.dead == true) {
				w = new fbIconAllEnemies();
			} else {
				w = new fbIcon2();
			}
			var littleScore = vgText(padZeros(player.score, 7), SMALL);
			var playerName = vgText("PLAYER 1", TINY);
			littleScore.x = 5;
			littleScore.y = 5;
			playerName.x = 5;
			playerName.y = 20;
			w.addChild(littleScore);
			w.addChild(playerName);
			var jpgSource:BitmapData = new BitmapData (w.width, w.height);
			jpgSource.draw(w);
			//var jpgEncoder:PNGEncoder = new PNGEncoder();
			var jpgStream:ByteArray = PNGEncoder.encode(jpgSource);
			var header:URLRequestHeader = new URLRequestHeader("Content-type", "application/octet-stream");
			var tempname = (new Date()).valueOf();
			var jpgURLRequest:URLRequest = new URLRequest(MovieClip(parent).domain + "/save_image.php?name=" + tempname + ".png");
			jpgURLRequest.requestHeaders.push(header);
			jpgURLRequest.method = URLRequestMethod.POST;
			jpgURLRequest.data = jpgStream;
			var imgLoader:URLLoader = new URLLoader();
			imgLoader.load(jpgURLRequest);
			
			var summary:String;
			if (player.dead) {
				summary = "A LOSER IS ME! Check out my lame score on the song '" + MovieClip(parent).video_title + "'.";								
			} else {
				summary = "A WINNER IS ME! Check out my score on the song '" + MovieClip(parent).video_title + "'.";
								 
			}
			if (MovieClip(parent).video_id) {
				summary += "\n\nThink you can do better?  Click here: http://darlingmypanda.com/?id=" + MovieClip(parent).video_id;
			} else {
				summary += "\n\nThink you can do better?  Go to http://darlingmypanda.com and click on '" + MovieClip(parent).video_title + "'!";
			}
			summary = escape(summary);
			var title:String = escape("DARLING MY PANDA VIOLENCE WALK");
			var requestStr = 'http://www.facebook.com/share.php?s=100&p[summary]=' + summary + '&p[title]=' + title + '&p[url]=' + MovieClip(parent).domain;
			requestStr += '&p[images][0]=' + MovieClip(parent).domain + '/' + tempname + '.png';
			var urlFacebookShare:URLRequest = new URLRequest(requestStr);
			urlFacebookShare.method = URLRequestMethod.GET;
			
			navigateToURL(urlFacebookShare, '_blank');	
		}
		
		function doNothing(event:Event):void {
			return;
		}
		
		function noNull(item:*, index:int, array:Array):Boolean {
			return(item != null);
		}
		
		function padZeros(num:int, length:int) {
			var numstr = String(num);
			var newstr = "";
			for(var i = 0; i < length - numstr.length; i++) {
				newstr += "0";
			} 
			newstr += numstr;
			return newstr;
		}
		
		function nextPos(currentPos:int, array:Array) {
			currentPos++;
			if (currentPos >= array.length) { currentPos = 0; }
			return currentPos;
		}
		
		
		// Sound Analysis
		function isPeak(attribute_type, lookahead:int = 0) {
			if (current_frame_num + lookahead > 0 && current_frame_num + lookahead + 1 < ALFframeBuffer.length) {
				return (ALFframeBuffer[current_frame_num + lookahead][attribute_type] > ALFframeBuffer[current_frame_num + lookahead - 1][attribute_type] &&
						ALFframeBuffer[current_frame_num + lookahead][attribute_type] > ALFframeBuffer[current_frame_num + lookahead + 1][attribute_type]);
			} else {
				return false;
			}
		}
		
		function onBeat() {
			return current_flux > BEAT_FLUX  && isPeak(FLUX_VAL);
		}
		
		function findPitch(freqArr:Array):Number {
			var freq:Number;
			var numSteps:int;
			var maxDist:Number;
			var freqDist:Number;
			
			var i:int = freqArr.length - 1;
			
			freq = freqArr[i];
			maxDist = 40000;
			//condense frequency to a 2 8va range (82.41 Hz corresponds to the low E (6th string on the guitar)
			//while(freq < 82.41 || freq > 164.82) {
			while(freq < 82.41 || freq > (164.82 * 4)) {
				if(freq < 82.41){ freq = freq * 2;}
				else{ freq = freq/2;}
			}
			
			for(var step:int = 0; step < 37; step++) {
				freqDist = Math.abs(freq - 82.41*Math.pow(2, step/36));
				if(freqDist < maxDist) {
					maxDist = freqDist;
					numSteps = step;
				}
			}
			
			return numSteps;
		}
	}	
}


