package
{
	import com.adobe.images.JPGEncoder;
	
	import flash.display.*;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Sound;
	import flash.net.FileFilter;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.text.TextField;
	import flash.ui.Keyboard;
	import flash.ui.Mouse;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class panda extends MovieClip
	{
		const MP3_PORTION = 0.75;
		
		
		var domain:String;
		
		var i:Number;
		
		
		// Sprites
		var heroes:Array = new Array();
		
		var alf_demo:gameAudioStuff;
		var mp3ready:Boolean = false;
		
		var loader:URLLoader;
		var yt_vars_loader:URLLoader;
		var flv_loader:URLLoader;
		
		var tempname;	
		var timer:Timer;
		var vars:URLVariables;
		var yt_vars:URLVariables;
		var video_duration:Number = 0;
		var video_id:String = "";
		var video_title:String = "";
		
		public function startPanda()
		{
			domain = root.loaderInfo.url.substr(0, root.loaderInfo.url.indexOf(".com") + 4);
			
			// Get youtube id if provided in URL
			trace("Ok.");
			var current_url:String = ExternalInterface.call("window.location.href.toString");
			var eqlpos:int = current_url.lastIndexOf("=");
			var youtube_id:String = null;
			if (eqlpos >= 0) {
				youtube_id = escape(current_url.substr(eqlpos + 1));
				//trace("CURRENT_URL" + current_url);
				//trace("YOUTUBE_ID: " + youtube_id);
			}
			
			alf_demo = null;
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.VARIABLES;
			
			yt_vars_loader = new URLLoader();
			yt_vars_loader.dataFormat = URLLoaderDataFormat.VARIABLES;
			yt_vars_loader.addEventListener(Event.COMPLETE, ytVarsComplete);
			
			flv_loader = new URLLoader();
			flv_loader.dataFormat = URLLoaderDataFormat.VARIABLES;
			flv_loader.addEventListener(Event.COMPLETE, flvComplete);
			
			timer = new Timer(1000);
			
			timer.addEventListener(TimerEvent.TIMER, tryMp3);
			titleSeq.btnConvert.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);
			titleSeq.btnBurningHeat.addEventListener(MouseEvent.MOUSE_DOWN, burningHeat);
			titleSeq.btnLeDisko.addEventListener(MouseEvent.MOUSE_DOWN, leDisko);
			titleSeq.btnShinchan.addEventListener(MouseEvent.MOUSE_DOWN, shinchan);
			titleSeq.btnTmi.addEventListener(MouseEvent.MOUSE_DOWN, tmi);
			titleSeq.btnBadRomance.addEventListener(MouseEvent.MOUSE_DOWN, badRomance);
			
			if (youtube_id) {
				titleSeq.yturl.text = "http://www.youtube.com/watch?v=" + youtube_id;
			}
			
			stop();
			
			
		}
		
		// Seems we need to add this event handler on the document class level
		function keyPress(keyboardEvent:KeyboardEvent) {
			alf_demo.keyPress(keyboardEvent);
		}
		
		function keyLift(keyboardEvent:KeyboardEvent) {
			alf_demo.keyLift(keyboardEvent);
		}
		
		function mouseDownHandler(event:MouseEvent):void {
			if (titleSeq.yturl.text == "") {
				tempname = "burning_heat";
				video_title = "Burning Heat";
				playmp3(event);
			} else if (titleSeq.yturl.text == "http://www.youtube.com/watch?v=ZO1jRJ7Z10w" || titleSeq.yturl.text == "sc") {
				tempname = "shinchan";
				video_title = "オラはにんきもの";
				playmp3(event);
			} else if (titleSeq.yturl.text == "http://www.youtube.com/watch?v=jJH38M723aU&ob=av3e" || titleSeq.yturl.text == "stg") {
				tempname = "le_disko";
				video_title = "Le Disko";
				playmp3(event);
			} else if (titleSeq.yturl.text == "http://www.youtube.com/watch?v=AZl_UF4-D_A" || titleSeq.yturl.text == "tmi") {
				tempname = "tmi";
				video_title = "Too Much Information";
				playmp3(event);
			} else if (titleSeq.yturl.text == "http://www.youtube.com/watch?v=t8C8frqCKKg" || titleSeq.yturl.text == "p") {
				tempname = "polovtsian";
				video_title = "The Polovtsian Dances";
				playmp3(event);
			} else if (titleSeq.yturl.text == "http://www.youtube.com/watch?v=qrO4YZeyl0I&ob=av3e" || titleSeq.yturl.text == "badromance") {
				tempname = "badromance";
				video_title = "Bad Romance";
				playmp3(event);
			} else {
				tempname = (new Date()).valueOf();
				alf_demo = new gameAudioStuff('./' + tempname + '.mp3', 600, 800);
				var request:URLRequest = new URLRequest(domain + "/convert_yt.php?tempname=" + tempname + "&video_url=" + titleSeq.yturl.text);
				loader.load(request);
				
				var yt_vars_request = new URLRequest(domain + "/get_yt_vars.php?tempname=" + tempname + "&video_url=" + titleSeq.yturl.text);
				yt_vars_loader.load(yt_vars_request);
								
				timer.start();

				Mouse.hide();
				addChild(alf_demo);
			}
			sky_bg.alpha = 100;
			titleSeq.visible = false;
			stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPress);
			stage.addEventListener(KeyboardEvent.KEY_UP, keyLift); 
		}
		
		function burningHeat(event:MouseEvent) {
			mouseDownHandler(event);
		}
		
		function leDisko(event:MouseEvent) {
			titleSeq.yturl.text = "http://www.youtube.com/watch?v=jJH38M723aU&ob=av3e";
			mouseDownHandler(event);
		}
		
		function shinchan(event:MouseEvent) {
			titleSeq.yturl.text = "http://www.youtube.com/watch?v=ZO1jRJ7Z10w";
			mouseDownHandler(event);
		}
		
		function tmi(event:MouseEvent) {
			titleSeq.yturl.text = "http://www.youtube.com/watch?v=AZl_UF4-D_A";
			mouseDownHandler(event);
		}
		
		function badRomance(event:MouseEvent) {
			titleSeq.yturl.text = "http://www.youtube.com/watch?v=qrO4YZeyl0I&ob=av3e";
			mouseDownHandler(event);
		}
		
		function ytVarsComplete(event:Event) {
			var yt_vars = new URLVariables(yt_vars_loader.data);
			video_title = yt_vars.video_title;
			video_duration = yt_vars.video_duration;
			video_id = yt_vars.video_id;
		}
		
		function flvComplete(event:Event) {
			var currentSize = flv_loader.data.currentSize;
			if (video_duration) {
				var expected_size = 128.0 * video_duration * 1000.0 / 8.0;
				var pct = Math.floor(currentSize / expected_size * 100 * MP3_PORTION);
				alf_demo.pctLoaded = String(pct) + "%";	 
				if (pct < 10) { alf_demo.pctLoaded = "0" + alf_demo.pctLoaded; }
			}
		}
		
		function tryMp3(event:TimerEvent) {
			var flv_request = new URLRequest(domain + "/check_current_audio_size.php?tempname=" + tempname + "&video_url=" + titleSeq.yturl.text);
			flv_loader.load(flv_request);
			
			var yt_vars_request = new URLRequest(domain + "/get_yt_vars.php?tempname=" + tempname + "&video_url=" + titleSeq.yturl.text);
			yt_vars_loader.load(yt_vars_request);
			vars = new URLVariables(loader.data);
			if(vars.mp3ready) {
				playmp3(event);
			}
		}
		
		function nomp3(event:IOErrorEvent) {}
		
		function playmp3(event:Event) {
			timer.stop();
			timer.removeEventListener(TimerEvent.TIMER, tryMp3);

			if (!alf_demo) {
				alf_demo = new gameAudioStuff('./' + tempname + '.mp3', 600, 800);
				addChild(alf_demo);
			}
			alf_demo.initALF(event);	
		}
		
		// This is just copied and pased from gameAudioStuff.as.  Should be in separate file or something.
		// Fonts
		var fontMap:Fonts = new Fonts();
		var fontMapMedium:FontsMedium = new FontsMedium();
		const SMALL = 0;
		const MEDIUM = 1;
		const LARGE = 2;
		const LETTER_WIDTH = 32;
		const LETTER_HEIGHT = LETTER_WIDTH;
		const MEDIUM_LW = 16;
		const MEDIUM_LH = MEDIUM_LW;
		function vgText(text:String, fontSize:uint = MEDIUM, xpos = 0, ypos = 0):Sprite {
			var myFontMap;
			var letter_width:uint;
			var letter_height:uint;
			
			if (fontSize == MEDIUM) {
				myFontMap = fontMapMedium; 
				letter_width = MEDIUM_LW;
				letter_height = MEDIUM_LH;
			} else {
				myFontMap = fontMap;
				letter_width = LETTER_WIDTH;
				letter_height = LETTER_HEIGHT;
			}
			
			text = text.toUpperCase();
			var textSprite:Sprite = new Sprite();
			var letter:BitmapData;
			var letterRect:Rectangle;
			var offsetFromA:int;
			var row_offset:int;
			var pt = new Point(0, 0);
			var letterBitmap:Bitmap;
			// In terms of grid position, not pixel coordinates
			const A_POS_X = 13;
			const A_POS_Y = 45;
			const FONT_BITMAP_WIDTH = 28;
			for (var i = 0; i < text.length; i++) {
				if (text.charAt(i) == '!') {
					offsetFromA = 28;   // ugly, but bitmap has its own character order
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
	}
	
	
	
}



