import flash.external.ExternalInterface;

import flash.display.Sprite;
import flash.display.MovieClip;

import flash.events.NetStatusEvent;
import flash.events.SecurityErrorEvent;
import flash.media.Video;
import flash.media.Camera;
import flash.media.Microphone;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.events.Event;

class StratusTest extends MovieClip {

    
    var cam:Camera;
    var vid:Video;
    
    var nc:NetConnection;
    
    var current:MovieClip;
    
    var listener_ns:NetStream;
    var incoming_ns:NetStream;
    
    var control_ns:NetStream;
    var outgoing_ns:NetStream;
    
    var listener:Bool;
    
    static function main(){        
        var objInstance = new StratusTest();        
    }

    function new() {
        super();

        current = flash.Lib.current;
        
        ExternalInterface.addCallback("startAsListener",startAsListener);
        ExternalInterface.addCallback("startAsConnector",startAsConnector);
    }
    
    function startAsConnector() {
        trace("Starting as Connector");
        listener = false;
        
        initConnect();        
    }
    
    function startAsListener() {
        trace("Starting as Listener");
        listener = true;
        
        initConnect();
    }
    
    function initConnect() {
        trace("Starting NetConnection...");
        nc = new NetConnection();
        nc.addEventListener(NetStatusEvent.NET_STATUS,ncListen);
        nc.connect("rtmfp://stratus.adobe.com/2eba02516e9fe7dca439d4be-55fd60f89cb3/");
    }
    
    function initCamera() {
        cam = Camera.getCamera(null); //default
        
        trace ("cam = " + cam);
    }
    
    function ncListen(event:NetStatusEvent) {
        switch (event.info.code) {
            case "NetConnection.Connect.Success":
                trace("NetConnection success. nearid=" + nc.nearID);
                connectStream();
            case "NetStream.Play.StreamNotFound":
                trace("Stream not found");
        }
    }
    
    function listenerHandler(event:NetStatusEvent) {
        trace("listener_ns event = " + event.info.code);
    }
    
    function controlHandler(event:NetStatusEvent) {
        trace("control_ns event = " + event.info.code);
    }
    
    function connectToListenerStream(farID:String) {
        trace("connectToListenerStream");
        control_ns = new NetStream(nc, farID);
		control_ns.addEventListener(NetStatusEvent.NET_STATUS, controlHandler);
		control_ns.play("listener_first");
		
		outgoing_ns = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
        outgoing_ns.addEventListener(NetStatusEvent.NET_STATUS, function (event:NetStatusEvent) {
            trace("outgoing_ns event = " + event.info.code);
        });
        
        if (cam != null) 
            outgoing_ns.attachCamera(cam);
        else
            trace ("No camera found.");
    
        outgoing_ns.publish("media-caller");
        
        outgoing_ns.client = {
          onPeerConnect : function(caller:NetStream) {
              trace("Callee connecting to media stream: " + caller.farID);
          }
        };
        
        incoming_ns = new NetStream(nc,farID);
        incoming_ns.addEventListener(NetStatusEvent.NET_STATUS, function (event:NetStatusEvent) {
            trace("incoming_ns event = " + event.info.code);
        });
        incoming_ns.play("media-callee");
        
        vid.attachNetStream(incoming_ns);
    }
        
    function publishListenerStream() {
        trace("publishListenerStream");
        
        if (nc == null)
            trace("nc = null!");
        
        listener_ns = new NetStream(nc,NetStream.DIRECT_CONNECTIONS);
        listener_ns.addEventListener(NetStatusEvent.NET_STATUS, listenerHandler);
        
        trace("publish listener_first");
        listener_ns.publish("listener_first");
        
        var listener_client = {
            onPeerConnect : onPeerConnect
        };
        
        listener_ns.client = listener_client;
        
        flash.Lib.trace("nearID = " + nc.nearID);
        ExternalInterface.call("setNearID", nc.nearID);
    }
    
    function onPeerConnect(caller:NetStream){
        trace("peerconnect");

        incoming_ns = new NetStream(nc,caller.farID);
        
        incoming_ns.addEventListener(NetStatusEvent.NET_STATUS, function (event:NetStatusEvent) {
            trace("incoming_ns event = " + event.info.code);
        });
        
        incoming_ns.receiveAudio(true);
        incoming_ns.receiveVideo(true);
        
        vid.attachNetStream(incoming_ns);
                
        trace("create outgoing");
        outgoing_ns = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
        outgoing_ns.addEventListener(NetStatusEvent.NET_STATUS, function (event:NetStatusEvent) {
            trace("outgoing_ns event = " + event.info.code);
        });
        
        if (cam == null)
            trace ("No camera attached.");
        else
            outgoing_ns.attachCamera(cam);
        
        outgoing_ns.publish("media-callee");
        
        incoming_ns.play("media-caller");
        
        vid.attachNetStream(incoming_ns);
    }
    
    function connectStream() {
        var currentURL = ExternalInterface.call('window.location.href.toString');
        
        var vid_width:Int = cast(320*1.3,Int);
        var vid_height:Int = cast(240*1.3,Int);
    
        vid = new Video(vid_width,vid_height);

        vid.x = 400;
        vid.y = 300;

        current.addChild(vid);

        trace("URL = " + currentURL);
        
        initCamera();            

        if (!listener) {
            trace("getting video");
            
            var farID = currentURL.split("?")[1];
            
            trace("will connect to farID = " + farID);
                        
            connectToListenerStream(farID);
        }
        else
        {
            //Publish
            cam.setQuality(350*1000,0);
            cam.setMode(vid_width,vid_height,30);

            cam.setLoopback(true);
            
            
            if (cam == null)
                trace ("No camera found.");
            else
                vid.attachCamera(cam);
            
/*            ns.attachCamera(cam);*/
            
            trace("nc = " + nc);
            publishListenerStream();
        }
    }

}