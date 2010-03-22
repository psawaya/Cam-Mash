import flash.events.Event;

class DrawEvent extends Event {

    public var penSize:Int;
    public var color:Dynamic;
    public var points:Dynamic;

    public static inline var DRAW:String = "DrawEvent";

    public function new(penSize:Int, color:Dynamic, points:Array<Array<Int>>) {
        super("DrawEvent");
        
        this.penSize = penSize;
        this.color = color;
        this.points = points;
    }
}