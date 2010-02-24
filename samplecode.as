
			import mx.charts.chartClasses.StackedSeries;
			import mx.formatters.DateFormatter;
			import flash.sampler.Sample;
			import mx.events.SliderEvent;
			import mx.events.FlexEvent;
			import mx.collections.ArrayCollection;
			import mx.events.ItemClickEvent;
			
			// stratus address, hosted by Adobe
			[Bindable] private var connectUrl:String = "rtmfp://stratus.adobe.com";

			// developer key, please insert your developer key here
			private const DeveloperKey:String = "your developer key";
			
			// please insert your webservice URL here for exchanging
			private const WebServiceUrl:String = "your webservice URL";
	
			// this is the connection to stratus
			private var netConnection:NetConnection;	
			
			// after connection to stratus, publish listener stream to wait for incoming call 
			private var listenerStream:NetStream;
			
			// caller's incoming stream that is connected to callee's listener stream
			private var controlStream:NetStream;
			
			// outgoing media stream (audio, video, text and some control messages)
			private var outgoingStream:NetStream;
			
			// incoming media stream (audio, video, text and some control messages)
			private var incomingStream:NetStream;
			
			// ID management serice
			private var idManager:AbstractIdManager;

			private var remoteVideo:Video;
			
			// login/registration state machine
			[Bindable] private var loginState:int;
			
			private const LoginNotConnected:int = 0;
			private const LoginConnecting:int = 1;
			private const LoginConnected:int = 2;
			private const LoginDisconnecting:int = 3;
			
			// call state machine
			[Bindable] private var callState:int;
			
			private const CallNotReady:int = 0;
			private const CallReady:int = 1;
			private const CallCalling:int = 2;
			private const CallRinging:int = 3;
			private const CallEstablished:int = 4;
			private const CallFailed:int = 5;
			
			// available microphone devices
			[Bindable] private var micNames:Array;
			private var micIndex:int = 0;
			
			// available camera deviced
			[Bindable] private var cameraNames:Array;
			private var cameraIndex:int = 0;
			
			private var activityTimer:Timer;
			
			// user name is saved in local shared object
			private var localSO:SharedObject;
					
			[Bindable] private var remoteName:String = "";
			
			private var callTimer:int;
			
			// charts
			private var audioRate:Array = new Array(30);
			[Bindable] private var audioRateDisplay:ArrayCollection = new ArrayCollection();
			private var videoRate:Array = new Array(30);
			[Bindable] private var videoRateDisplay:ArrayCollection = new ArrayCollection();
			private var srtt:Array = new Array(30);
			[Bindable] private var srttDisplay:ArrayCollection = new ArrayCollection();
			
			private const defaultMacCamera:String = "USB Video Class Video";
					
			// called when application is loaded            		
			private function init():void
			{		
				status("Player: " + Capabilities.version + "\n");
				
				loginState = LoginNotConnected;
				callState = CallNotReady;
				
				localSO = SharedObject.getLocal("videoPhoneSettings");
				if (localSO.data.hasOwnProperty("user"))
				{
					userNameInput.text = localSO.data.user;
				}
								
				var mics:Array = Microphone.names;
				if (mics)
				{
					micNames = mics;
				}
				else
				{
					status("No microphone available.\n");
				}
				
				var cameras:Array = Camera.names;
				if (cameras)
				{
					cameraNames = cameras;
				}
				else
				{
					status("No camera available.\n");
				}
			
				// statistics timer
				activityTimer = new Timer(1000);
				activityTimer.addEventListener(TimerEvent.TIMER, onActivityTimer);
				activityTimer.start();
						
				// selected mic device
				micIndex = 0;
				if (localSO.data.hasOwnProperty("micIndex"))
				{
					micIndex = localSO.data.micIndex;
				}
				
				micSelection.selectedIndex = micIndex;
				
				// set Mac default camera
				if (Capabilities.os.search("Mac") != -1)
				{
					for (cameraIndex = 0; cameraIndex < cameras.length; cameraIndex++)
					{
						if (cameras[cameraIndex] == defaultMacCamera)
						{
							break;
						}
					}	
				}
					
				// selected camera device
				if (localSO.data.hasOwnProperty("cameraIndex"))
				{
					cameraIndex = localSO.data.cameraIndex;
				}
				
				cameraSelection.selectedIndex = cameraIndex;
				
				// mic volume
				var micVolume:int = 50;
				if (localSO.data.hasOwnProperty("micVolume"))
				{
					micVolume = localSO.data.micVolume;
				}
				
				micVolumeSlider.value = micVolume;
				
				// speaker volume
				var speakerVolume:Number = 0.8;
				if (localSO.data.hasOwnProperty("speakerVolume"))
				{
					speakerVolume = localSO.data.speakerVolume;
				}
				
				speakerVolumeSlider.value = speakerVolume;
				
				// configure audio and video
				var mic:Microphone = Microphone.getMicrophone(micIndex);
				if (mic)
				{
					mic.codec = SoundCodec.SPEEX;
					mic.setSilenceLevel(0);
					mic.framesPerPacket = 1;
					mic.gain = micVolume;
						
					mic.addEventListener(StatusEvent.STATUS, onDeviceStatus);
					mic.addEventListener(ActivityEvent.ACTIVITY, onDeviceActivity);
				}
				
				var camera:Camera = Camera.getCamera(cameraIndex.toString());
				if (camera)
				{
					camera.addEventListener(StatusEvent.STATUS, onDeviceStatus);
					camera.addEventListener(ActivityEvent.ACTIVITY, onDeviceActivity);
					camera.setMode(320, 240, 15);
					camera.setQuality(0, 80);
				}
			}
					
			private function status(msg:String):void
			{
				statusArea.text += msg;
				statusArea.validateNow();
				statusArea.verticalScrollPosition = statusArea.textHeight;
				trace("ScriptDebug: " + msg);
			}
			
			// user clicked connect
			private function onConnect():void
			{
				statusArea.text = "";
				
				localSO.data.user = userNameInput.text;
				localSO.flush();
				
				netConnection = new NetConnection();
				netConnection.addEventListener(NetStatusEvent.NET_STATUS, netConnectionHandler);
				netConnection.connect(connectUrl + "/" + DeveloperKey);
				
				loginState = LoginConnecting;	
				
				status("Connecting to " + connectUrl + "\n");
			}
			
			private function netConnectionHandler(event:NetStatusEvent):void
			{
				status("NetConnection event: " + event.info.code + "\n");
				
            	switch (event.info.code)
            	{
                	case "NetConnection.Connect.Success":
                		connectSuccess();
                    	break;
                    	
                    case "NetConnection.Connect.Closed":
                    	loginState = LoginNotConnected;
                    	callState = CallNotReady;
                    	break;
                    	
                    case "NetStream.Connect.Success":
                    	// we get this when other party connects to our control stream our outgoing stream
                    	status("Connection from: " + event.info.stream.farID + "\n");
                    	break;
                    	
                    case "NetConnection.Connect.Failed":
                    	status("Unable to connect to " + connectUrl + "\n");
                    	loginState = LoginNotConnected;
                    	break;
                    	
                    case "NetStream.Connect.Closed":
                    	onHangup();
                    	break;
             	}
         	}
			
			private function listenerHandler(event:NetStatusEvent):void
			{
				status("Listener event: " + event.info.code + "\n");
			}
			
			private function controlHandler(event:NetStatusEvent):void
			{
				status("Control event: " + event.info.code + "\n");
			}
			
			private function outgoingStreamHandler(event:NetStatusEvent):void
			{
				status("Outgoing stream event: " + event.info.code + "\n");
            	switch (event.info.code)
            	{
            		case "NetStream.Play.Start":
            			if (callState == CallCalling)
            			{
            				outgoingStream.send("onIncomingCall", userNameInput.text);
            			}
            			break;
            	}
			}
			
			private function incomingStreamHandler(event:NetStatusEvent):void
			{
				status("Incoming stream event: " + event.info.code + "\n");
            	switch (event.info.code)
            	{
            		case "NetStream.Play.UnpublishNotify":
            			onHangup();
            			break;
             	}
			}
			
			// connection to stratus succeeded and we register our fingerprint with a simple web service
			// other clients use the web service to look up our fingerprint
			private function connectSuccess():void
			{
				status("Connected, my ID: " + netConnection.nearID + "\n");
                
              	idManager = new HttpIdManager();
              	idManager.addEventListener("registerSuccess", idManagerEvent);
              	idManager.addEventListener("registerFailure", idManagerEvent);
              	idManager.addEventListener("lookupFailure", idManagerEvent);
              	idManager.addEventListener("lookupSuccess", idManagerEvent);
              	idManager.addEventListener("idManagerError", idManagerEvent);
              	
              	idManager.service = WebServiceUrl;
              	idManager.register(userNameInput.text, netConnection.nearID);
			}
			
			private function completeRegistration():void
			{
				// start the control stream that will listen to incoming calls
				listenerStream = new NetStream(netConnection, NetStream.DIRECT_CONNECTIONS);
				listenerStream.addEventListener(NetStatusEvent.NET_STATUS, listenerHandler);
				listenerStream.publish("control" + userNameInput.text);
							
				var c:Object = new Object
				c.onPeerConnect = function(caller:NetStream):Boolean
				{
					status("Caller connecting to listener stream: " + caller.farID + "\n");
								
					if (callState == CallReady)
					{
						callState = CallRinging;
									
						// callee subscribes to media, to be able to get the remote user name
						incomingStream = new NetStream(netConnection, caller.farID);
						incomingStream.addEventListener(NetStatusEvent.NET_STATUS, incomingStreamHandler);
						incomingStream.play("media-caller");
						
						// set volume for incoming stream
						var st:SoundTransform = new SoundTransform(speakerVolumeSlider.value);
						incomingStream.soundTransform = st;
									
						incomingStream.receiveAudio(false);
						incomingStream.receiveVideo(false);
									
						var i:Object = new Object;
						i.onIncomingCall = function(caller:String):void
						{
							if (callState != CallRinging)
							{
								status("onIncomingCall: Wrong call state: " + callState + "\n");
								return;
							}
							remoteName = caller;
									
							status("Incoming call from: " + caller + "\n");
						}
						
						i.onIm = function(name:String, text:String):void
						{
							textOutput.text += name + ": " + text + "\n";
							textOutput.validateNow();
							textOutput.verticalScrollPosition = textOutput.textHeight;
						}
						incomingStream.client = i;
									
						return true;
					}
						
					status("onPeerConnect: all rejected due to state: " + callState + "\n");
		
					return false;
				}
							
				listenerStream.client = c;
							
				callState = CallReady;
			}
			
			private function placeCall(user:String, identity:String):void
			{
				status("Calling " + user + ", id: " + identity + "\n");
							
				if (identity.length != 64)
				{	
					status("Invalid remote ID, call failed\n");
					callState = CallFailed;
					return;
				}
							
				// caller subsrcibes to callee's listener stream 
				controlStream = new NetStream(netConnection, identity);
				controlStream.addEventListener(NetStatusEvent.NET_STATUS, controlHandler);
				controlStream.play("control" + user);
							
				// caller publishes media stream
				outgoingStream = new NetStream(netConnection, NetStream.DIRECT_CONNECTIONS);
				outgoingStream.addEventListener(NetStatusEvent.NET_STATUS, outgoingStreamHandler);
				outgoingStream.publish("media-caller");
							
				var o:Object = new Object
				o.onPeerConnect = function(caller:NetStream):Boolean
				{
					status("Callee connecting to media stream: " + caller.farID + "\n");

					return true; 
				}
				outgoingStream.client = o;

				startAudio();					
				startVideo();
														
				// caller subscribes to callee's media stream
				incomingStream = new NetStream(netConnection, identity);
				incomingStream.addEventListener(NetStatusEvent.NET_STATUS, incomingStreamHandler);
				incomingStream.play("media-callee");
				
				// set volume for incoming stream
				var st:SoundTransform = new SoundTransform(speakerVolumeSlider.value);
				incomingStream.soundTransform = st;
							
				var i:Object = new Object;
				i.onCallAccepted = function(callee:String):void
				{
					if (callState != CallCalling)
					{
						status("onCallAccepted: Wrong call state: " + callState + "\n");
						return;
					}
								
            		callState = CallEstablished;
            											
					status("Call accepted by " + callee + "\n");
				}
				i.onIm = function(name:String, text:String):void
				{
					textOutput.text += name + ": " + text + "\n";
				}
				incomingStream.client = i;
								
				remoteVideo = new Video();
				remoteVideo.width = 320;
				remoteVideo.height = 240;
				remoteVideo.attachNetStream(incomingStream);
				remoteVideoDisplay.addChild(remoteVideo);
							
				remoteName = user;
				callState = CallCalling;
			}
					
			// process successful response from web service		
			private function idManagerEvent(e:Event):void
			{
				status("ID event: " + e.type + "\n");
				
				if (e.type == "registerSuccess")
				{
					switch (loginState)
					{
						case LoginConnecting:
							loginState = LoginConnected;
							break;
						case LoginDisconnecting:
						case LoginNotConnected:
							loginState = LoginNotConnected;
							return;
						case LoginConnected:
							return;
					}	
							
					completeRegistration();
				}
				else if (e.type == "lookupSuccess")
				{
					// party query response
					var i:IdManagerEvent = e as IdManagerEvent;
					
					placeCall(i.user, i.id);	
				}
				else
				{
					// all error messages ar IdManagerError type
					var error:IdManagerError = e as IdManagerError;
					status("Error description: " + error.description + "\n")
					
					onDisconnect();
				}
			}
			
			// user clicked accept button
			private function acceptCall():void
			{
				incomingStream.receiveAudio(true);
				incomingStream.receiveVideo(true);
				
				remoteVideo = new Video();
				remoteVideo.width = 320;
				remoteVideo.height = 240;
				remoteVideo.attachNetStream(incomingStream);
				remoteVideoDisplay.addChild(remoteVideo);
								
				// callee publishes media
				outgoingStream = new NetStream(netConnection, NetStream.DIRECT_CONNECTIONS);
				outgoingStream.addEventListener(NetStatusEvent.NET_STATUS, outgoingStreamHandler);
				outgoingStream.publish("media-callee");
				
				var o:Object = new Object
				o.onPeerConnect = function(caller:NetStream):Boolean
				{
					status("Caller connecting to media stream: " + caller.farID + "\n");
								           			
					return true; 
				}
				outgoingStream.client = o;
				
				outgoingStream.send("onCallAccepted", userNameInput.text);
				
				startVideo();
				startAudio();
									
				callState = CallEstablished;
			}
			
			private function cancelCall():void
			{
				onHangup();
			}
			
			private function rejectCall():void
			{
				onHangup();
			}
						
			private function onDisconnect():void
			{
				status("Disconnecting.\n");
				
				onHangup();
				
				callState = CallNotReady;
				
				if (idManager)
				{
					idManager.unregister();
					idManager = null;
				}
				
				loginState = LoginNotConnected;
				
				netConnection.close();
				netConnection = null;
			}
		
			// placing a call
			private function onCall():void
			{
				if (netConnection && netConnection.connected)
				{
					if (calleeInput.text.length == 0)
					{
						status("Please enter name to call\n");
						return;
					}
					
					// first, we need to lookup callee's fingerprint using the web service
					if (idManager)
					{
						idManager.lookup(calleeInput.text);
					}
					else
					{
						status("Not registered.\n");
						return;
					}
				}
				else
				{
					status("Not connected.\n");
				}
			}
			
			private function startAudio():void
			{
				if (sendAudioCheckbox.selected)
				{
					var mic:Microphone = Microphone.getMicrophone(micIndex);
					if (mic && outgoingStream)
					{
						outgoingStream.attachAudio(mic);
					}
				}
				else
				{
					if (outgoingStream)
					{
						outgoingStream.attachAudio(null);
					}
				}
			}
			
			private function startVideo():void
			{
				if (sendVideoCheckbox.selected)
				{
					var camera:Camera = Camera.getCamera(cameraIndex.toString());
					if (camera)
					{
						localVideoDisplay.attachCamera(camera);
						if (outgoingStream)
						{
							outgoingStream.attachCamera(camera);
						}
					}
				}
				else
				{
					localVideoDisplay.attachCamera(null);
					if (outgoingStream)
					{
						outgoingStream.attachCamera(null);
					}
				}
			}
						
			// this function is called in every second to update charts, microhone level, and call timer
			private function onActivityTimer(e:TimerEvent):void
			{
				var mic:Microphone = Microphone.getMicrophone(micIndex);
				micActivityLabel.text = mic.activityLevel.toString();
				
				if (callState == CallEstablished && incomingStream && outgoingStream && outgoingStream.peerStreams.length == 1)
				{
					var recvInfo:NetStreamInfo = incomingStream.info;
					var sentInfo:NetStreamInfo = outgoingStream.peerStreams[0].info;
					
					audioRate.shift();
					var a:Object = new Object;
					a.Recv = recvInfo.audioBytesPerSecond * 8 / 1024;
					a.Sent = sentInfo.audioBytesPerSecond * 8 / 1024;
					audioRate.push(a);
					audioRateDisplay.source = audioRate;
					
					videoRate.shift();
					var v:Object = new Object;
					v.Recv = recvInfo.videoBytesPerSecond * 8 / 1024;
					v.Sent = sentInfo.videoBytesPerSecond * 8 / 1024;
					videoRate.push(v);
					videoRateDisplay.source = videoRate;
					
					srtt.shift();
					var s:Object = new Object;
					s.Data = recvInfo.SRTT;
					srtt.push(s);
					srttDisplay.source = srtt;
				}

				if (callState == CallEstablished)
				{
					callTimer++;
					var elapsed:Date = new Date(2008, 4, 12);
					elapsed.setTime(elapsed.getTime() + callTimer * 1000);
					var formatter:DateFormatter = new DateFormatter();
					var format:String = "JJ:NN:SS";
					if (callTimer < 60)
					{
						format = "SS";
					}
					else if (callTimer < 60 * 60)
					{
						format = "NN:SS";
					}
					formatter.formatString = format 
					callTimerText.text = formatter.format(elapsed);
				}
			}
			
			private function onDeviceStatus(e:StatusEvent):void
			{
				status("Device status: " + e.code + "\n");
			}
			
			private function onDeviceActivity(e:ActivityEvent):void
			{
//				status("Device activity: " + e.activating + "\n");
			}
					
			private function onHangup():void
			{
				status("Hanging up call\n");
				
				calleeInput.text = "";
				callState = CallReady;
				
				if (incomingStream)
				{
					incomingStream.close();
					incomingStream.removeEventListener(NetStatusEvent.NET_STATUS, incomingStreamHandler);
				}
				
				if (outgoingStream)
				{
					outgoingStream.close();
					outgoingStream.removeEventListener(NetStatusEvent.NET_STATUS, outgoingStreamHandler);
				}
				
				if (controlStream)
				{
					controlStream.close();
					controlStream.removeEventListener(NetStatusEvent.NET_STATUS, controlHandler);
				}
				
				incomingStream = null;
				outgoingStream = null;
				controlStream = null;
				
				remoteName = "";
				
				receiveAudioCheckbox.selected = true;
				receiveVideoCheckbox.selected = true;
				
				callTimer = 0;
			}
			
			private function speakerVolumeChanged(e:SliderEvent):void
			{
				if (incomingStream)
				{
					var st:SoundTransform = new SoundTransform(e.value);
					incomingStream.soundTransform = st;
					
					status("Setting speaker volume to: " + e.value + "\n");
				}
				
				localSO.data.speakerVolume = e.value;
				localSO.flush();
			}
			
			private function micVolumeChanged(e:SliderEvent):void
			{
				var mic:Microphone = Microphone.getMicrophone(micIndex);
				if (mic)
				{
					mic.gain = e.value;
					
					localSO.data.micVolume = e.value;
					localSO.flush();
					
					status("Setting mic volume to: " + e.value + "\n");
				}
			}
			
			// sending text message
			private function onSend():void
			{
				var msg:String = textInput.text; 
				if (msg.length != 0 && outgoingStream)
				{
					textOutput.text += userNameInput.text + ": " + msg + "\n";
					outgoingStream.send("onIm", userNameInput.text, msg);
					textInput.text = "";
				}
			}
			
			private function micChanged(event:Event):void
			{
				var oldMicIndex:int = micIndex;
				micIndex = micSelection.selectedIndex;
				
				var mic:Microphone = Microphone.getMicrophone(micIndex);
				var oldMic:Microphone = Microphone.getMicrophone(oldMicIndex);
					
				mic.codec = oldMic.codec;
				mic.rate = oldMic.rate;
				mic.encodeQuality = oldMic.encodeQuality;
				mic.framesPerPacket = oldMic.framesPerPacket;
				mic.gain = oldMic.gain;
				mic.setSilenceLevel(oldMic.silenceLevel);
				
				if (callState == CallEstablished)
				{	
					outgoingStream.attachAudio(mic);
				}
				
				localSO.data.micIndex = micIndex;
				localSO.flush();
			}
						
			private function cameraChanged(event:Event):void
			{
				var oldCameraIndex:int = cameraIndex;
				cameraIndex = cameraSelection.selectedIndex;
				
				var camera:Camera = Camera.getCamera(cameraIndex.toString());
				var oldCamera:Camera = Camera.getCamera(oldCameraIndex.toString());
				
				camera.setMode(320, 240, 15);
				camera.setQuality(0, oldCamera.quality);
				
				// when user changes video device, we want to show preview
				localVideoDisplay.attachCamera(camera);
					
				if (callState == CallEstablished)
				{	
					outgoingStream.attachCamera(camera);
				}
				
				localSO.data.cameraIndex = cameraIndex;
				localSO.flush();
			}
			
			private function videoQualityChanged(e:SliderEvent):void
			{
				var camera:Camera = Camera.getCamera(cameraIndex.toString());
				if (camera)
				{
					camera.setQuality(0, e.value);
					status("Setting camera quality to: " + e.value + "\n");
				}
			}
			
			private function onAudioMuted():void
			{
				if (incomingStream)
				{
					incomingStream.receiveAudio(receiveAudioCheckbox.selected);
				}
			}
			
			private function onVideoPaused():void
			{
				if (incomingStream)
				{
					incomingStream.receiveVideo(receiveVideoCheckbox.selected);
				}
			}
			
			private function handleCodecChange(event:ItemClickEvent):void
			{
				var mic:Microphone = Microphone.getMicrophone(micIndex);
				if (mic)
				{
					if (event.currentTarget.selectedValue == "speex")
					{
						codecPropertyStack.selectedChild = speexCanvas;
						mic.codec = SoundCodec.SPEEX;
						mic.framesPerPacket = 1;
						mic.encodeQuality = int(speexQualitySelector.selectedItem);
						mic.setSilenceLevel(0);
					}
					else
					{
						codecPropertyStack.selectedChild = nellymoserCanvas;
						
						mic.codec = SoundCodec.NELLYMOSER;
						mic.rate =  int(nellymoserRateSelector.selectedItem);
						mic.setSilenceLevel(10);
					}
				}
   			}
   			
   			private function speexQuality(e:Event):void
   			{
   				var mic:Microphone = Microphone.getMicrophone(micIndex);
   				if (mic)
   				{
   					var quality:int = int(ComboBox(e.target).selectedItem);
   					mic.encodeQuality = quality;
   				
   					status("Setting speex quality to: " + quality);
   				}
   			}
   			
   			private function nellymoserRate(e:Event):void
   			{
   				var mic:Microphone = Microphone.getMicrophone(micIndex);
   				if (mic)
   				{
   					var rate:int = int(ComboBox(e.target).selectedItem);
   					mic.rate = rate;
   					
   					status("Setting Nellymoser rate to: " + rate);
   				}
   			}
