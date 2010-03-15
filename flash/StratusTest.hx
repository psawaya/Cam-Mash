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
import flash.system.Security;
import flash.system.SecurityPanel;
import flash.system.Capabilities;

class StratusTest {

    static var RTMFP_SERVER = "rtmfp://stratus.adobe.com/";
    static var DEV_KEY = "2eba02516e9fe7dca439d4be-55fd60f89cb3";

    var mic:Microphone;
    var cam:Camera;
    var peerVideo:Video;
    var localVideo:Video;

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
        current = flash.Lib.current;

        ExternalInterface.addCallback("startAsListener",startAsListener);
        ExternalInterface.addCallback("startAsConnector",startAsConnector);

        var vid_width:Int = cast(320*1.0,Int);
        var vid_height:Int = cast(240*1.0,Int);

        peerVideo = new Video(vid_width, vid_height);
        peerVideo.x = 600-vid_width;
        peerVideo.y = 0;

        localVideo = new Video(vid_width, vid_height);
        localVideo.x = 0;
        localVideo.y = 480-vid_height;

        current.addChild(peerVideo);
        current.addChild(localVideo);

        initMicrophone();

        initCamera(vid_width, vid_height, 30);

        if (cam != null)
            /* Attach the loopback video feed so the client can see themself */
            localVideo.attachCamera(cam);
    }

    function startAsConnector() {
        trace("Starting as Connector");
        listener = false;

        initConnect();
    }

    function startAsListener() {
        trace("Starting as Listener");
        trace("Capabilities: " + Capabilities.version);
        listener = true;

        initConnect();
    }

    function initConnect() {
        trace("Starting NetConnection...");
        nc = new NetConnection();
        nc.addEventListener(NetStatusEvent.NET_STATUS,ncListen);
        nc.connect(RTMFP_SERVER + DEV_KEY);
    }

    function initCamera(width:Int, height:Int, fps:Int) {
        // XXX: Getting the camera when it is already acquired by
        // another application causes the feed to cut out on linux
        cam = Camera.getCamera();

        trace ("cam = " + cam.name);
        if (cam == null)
            trace ("No camera found.");
        else {
            // Where does this bandwidth number come from?
            cam.setQuality(350*1000,0); // Args are: bandwidth, quality
            cam.setMode(width,height,fps);
            // setLoopback specifies whether to compress the local feed (if true)
            // as if it were being processed for transmission, or to display it
            // uncompressed (false). Compression requires substantially more
            // computation than just displaying the uncompressed stream so we
            // should leave this set to false.
            cam.setLoopback(false); 
        }
    }

    function initMicrophone() {
        mic = Microphone.getMicrophone();
        mic.setLoopBack(false);

        if (mic != null) {
            mic.setUseEchoSuppression(true);
            //mic.addEventListener(ActivityEvent.ACTIVITY, activityHandler);
            //mic.addEventListener(StatusEvent.STATUS, statusHandler);
        }


        trace ("mic = " + mic.name);
    }

    function ncListen(event:NetStatusEvent) {
        switch (event.info.code) {
            case "NetConnection.Connect.Success":
                trace("NetConnection success. nearid=" + nc.nearID);
                connectStream();
            case "NetStream.Play.StreamNotFound":
                trace("Stream not found");
            case "NetStream.Connect.Closed":
                trace("Connection closed");
                onHangup();
        }
    }

    function connectToListenerStream(farID:String) {
        trace("connectToListenerStream");
        control_ns = new NetStream(nc, farID);
		control_ns.addEventListener(NetStatusEvent.NET_STATUS, controlHandler);
		control_ns.play("control");

        incoming_ns = new NetStream(nc,farID);
        incoming_ns.addEventListener(NetStatusEvent.NET_STATUS, incomingHandler);

        publishOutStream();

        incoming_ns.play("media");

        peerVideo.attachNetStream(incoming_ns);
    }

    function publishListenerStream() {
        trace("publishListenerStream");

        if (nc == null)
            trace("nc = null!");

        listener_ns = new NetStream(nc,NetStream.DIRECT_CONNECTIONS);
        listener_ns.addEventListener(NetStatusEvent.NET_STATUS, listenerHandler);

        trace("publish listener_first");
        listener_ns.publish("control");

        var listener_client = {
            onPeerConnect : onPeerConnect
        };

        listener_ns.client = listener_client;

        trace("nearID = " + nc.nearID);
        ExternalInterface.call("setNearID", nc.nearID);
    }

    function onPeerConnect(caller:NetStream){
        trace("peerconnect");

        incoming_ns = new NetStream(nc,caller.farID);
        incoming_ns.addEventListener(NetStatusEvent.NET_STATUS, incomingHandler);

        incoming_ns.receiveAudio(true);
        incoming_ns.receiveVideo(true);

        publishOutStream();

        incoming_ns.play("media");

        peerVideo.attachNetStream(incoming_ns);
    }

    function publishOutStream() {
        trace("Creating outgoing stream");
        outgoing_ns = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
        outgoing_ns.addEventListener(NetStatusEvent.NET_STATUS, outgoingHandler);

        if (cam == null)
            trace ("No camera found.");
        else
            outgoing_ns.attachCamera(cam);

        if (mic == null)
            trace ("No microphone found.");
        else
            outgoing_ns.attachAudio(mic);

        outgoing_ns.client = {
          onPeerConnect : function(caller:NetStream) {
              trace("Received connection from " + caller.farID);
          }
        };

        outgoing_ns.publish("media");
    }

    function connectStream() {
        var currentURL = ExternalInterface.call('window.location.href.toString');
        trace("URL = " + currentURL);

        if (listener) { /* Client is publishing their stream to receive calls */
            trace("nc = " + nc);
            publishListenerStream();
        } else { /* Client is initiating a call */
            // XXX: Is there a URL parsing library so we can have additional query terms?
            var farID = currentURL.split("?")[1];
            trace("will connect to farID = " + farID);
            connectToListenerStream(farID);
        }
    }

    function onHangup() {
        peerVideo.clear();

        if (incoming_ns != null) {
            incoming_ns.close();
		    incoming_ns.removeEventListener(NetStatusEvent.NET_STATUS, incomingHandler);
        }

        if (outgoing_ns != null) {
            outgoing_ns.close();
	        outgoing_ns.removeEventListener(NetStatusEvent.NET_STATUS, outgoingHandler);
        }

        if (control_ns != null) {
            control_ns.close();
	        control_ns.removeEventListener(NetStatusEvent.NET_STATUS, controlHandler);
        }

        incoming_ns = null;
        outgoing_ns = null;
        control_ns = null;
    }

    /* Handlers */
    function listenerHandler(event:NetStatusEvent) {
        trace("listener_ns event = " + event.info.code);
    }

    function controlHandler(event:NetStatusEvent) {
        trace("control_ns event = " + event.info.code);
    }

    function incomingHandler(event:NetStatusEvent) {
        trace("incoming_ns event = " + event.info.code);
    }

    function outgoingHandler(event:NetStatusEvent) {
        trace("outgoing_ns event = " + event.info.code);
    }

}
