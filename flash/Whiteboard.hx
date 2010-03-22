import flash.display.Sprite;
import flash.display.MovieClip;

import flash.events.EventDispatcher;
import flash.events.MouseEvent;

class Whiteboard extends MovieClip {

    var color:Dynamic; //TODO: figure out what type this should be. Long?
    
    var drawing:Bool;
    
    var penSize:Int;
    
    var points:Dynamic;
    
    var drawWidth:Int;
    var drawHeight:Int;
    
    var drawCanvas:MovieClip;
    
    public function new (drawWidth:Int, drawHeight:Int) {
        super();
        
        this.color = 0x000000;
        
        this.drawing = false;
        
        this.penSize = 3;
        
        drawCanvas = new MovieClip();
        
        this.drawHeight = drawHeight;
        this.drawWidth = drawWidth;
        
        drawCanvas.graphics.beginFill(0xffffff);
        drawCanvas.graphics.drawRect(0,0,drawWidth,drawHeight);
        drawCanvas.graphics.endFill();
        
        addChild(drawCanvas);
        
        addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        
        createButtons();
    }
    
    public function updateWhiteboard(penSize:Int, color:Dynamic, points:Array<Array<Int>>) {        
        trace("len = " + points.length);
        
        //TODO: Consider using drawPath?

        drawCanvas.graphics.lineStyle(penSize, color, 1.0);
        
        for (i in 0...points.length) {
            if (i > 0)
                drawCanvas.graphics.lineTo(points[i][0],points[i][1]);

            drawCanvas.graphics.moveTo(points[i][0],points[i][1]);
        }
    }
    
    function createButtons() {
        var colors = [0x000000, 0xffffff, 0xff0000, 0x00ff00, 0x0000ff,0x783030,0x483078,0x301818,0xD8D860,0xF0C060];
        
        for (i in 0...colors.length) {
            var newButton = new Sprite();

            addChild(newButton);

            newButton.x = i*16;
            newButton.y = drawHeight;
            
            newButton.graphics.beginFill(colors[i]);
            newButton.graphics.drawRect(0,0,16,16);
            newButton.graphics.endFill();
            
            var thisInstance = this;
            
            newButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
                thisInstance.color = colors[i];
            });
        }
        
        var sizes = [1,3,5,10];
        
        for (i in 0...sizes.length) {
            var newButton = new Sprite();

            addChild(newButton);

            newButton.x = i*16 + 16*colors.length + 100;
            newButton.y = drawHeight;

            newButton.graphics.beginFill(0xffffff);
            newButton.graphics.drawRect(0,0,16,16);
            newButton.graphics.endFill();
            
            newButton.graphics.beginFill(0x000000);
            
            var size = (i+1)*2;
            
            newButton.graphics.drawEllipse(16/2 - (size/2), 16/2 - (size/2), size, size);
            newButton.graphics.endFill();
            
            var thisInstance = this;
            
            newButton.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
                thisInstance.penSize = sizes[i];
            });
        }
    }
    
    function setPenSize(penSize:Int) {
        this.penSize = penSize;
    }
    
    function setColor(color:Dynamic) {
        this.color = color;
    }
    
    function onMouseDown(e:MouseEvent) {
        drawing = true;
        
        addEventListener(MouseEvent.MOUSE_MOVE, onMouseOver);
        
        points = new Array<Array<Int>> ();
        points.push ([e.localX, e.localY]);
        
        drawCanvas.graphics.lineStyle(penSize, color, 1.0);
        
        drawCanvas.graphics.moveTo(e.localX,e.localY);
    }
    
    function onMouseUp(e:MouseEvent) {
        drawing = false;
        
        removeEventListener(MouseEvent.MOUSE_MOVE, onMouseOver);

        dispatchEvent (new DrawEvent(penSize, color, points));
    }
    
    function onMouseOver(e:MouseEvent) {        
        points.push ([e.localX, e.localY]);
        
        drawCanvas.graphics.lineTo(e.localX,e.localY);
        drawCanvas.graphics.moveTo(e.localX,e.localY);
    }
}