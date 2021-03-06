package org.friendlytalk.core.application
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.MicrophoneEnhancedOptions;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.Capabilities;
	import flash.utils.getDefinitionByName;
	
	import org.friendlytalk.core.domain.Broadcaster;
	import org.friendlytalk.core.domain.Media;
	import org.friendlytalk.core.domain.Room;
	import org.friendlytalk.core.infrastructure.Connector;
	import org.friendlytalk.core.infrastructure.Publisher;
	import org.friendlytalk.home.events.ConnectEvent;

	public class FrontController
	{
		public function FrontController()
		{
		}
		
		//----------------------------------------------------------------------
		//
		//	Variables
		//
		//----------------------------------------------------------------------
		
		public var connector:Connector;
		
		public var publisher:Publisher;
		
		//----------------------------------------------------------------------
		//
		//	Properties
		//
		//----------------------------------------------------------------------
		
		public var room:Room;
		
		public var media:Media;
		
		//----------------------------------------------------------------------
		//
		//	Commands
		//
		//----------------------------------------------------------------------
		
		public function connect(event:ConnectEvent):void
		{
			if (!this.room) return;
			
			this.room.connecting = true;
			
			this.connector.addEventListener(ErrorEvent.ERROR, errorHandler);
			this.connector.addEventListener(Event.CONNECT, connectHandler);
			this.connector.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			
			this.connector.connect(event.room);
		}
		
		public function publish():void
		{
			if (!this.room || !this.room.connected) return;
			
			var connection:NetConnection = this.connector.getNetConnection();
			var stream:NetStream = this.connector.getBroadcastNetStream();
			
			if (this.media)
			{
				this.media.camera = this.publisher.getDefaultCamera();
				this.media.microphone = this.publisher.getDefaultMicrophone();
			}
			
			this.publisher.publish(connection, stream, !this.media.videoMuted, !this.media.audioMuted);
		}
		
		public function toggleCamera():void
		{
			this.media.videoMuted = !this.media.videoMuted;
			
			var stream:NetStream = this.connector.getBroadcastNetStream();
			
			if (this.media.videoMuted) 
				this.publisher.muteCamera(stream);
			else
				this.publisher.unmuteCamera(stream);
		}

		public function toggleMicrophone():void
		{
			this.media.audioMuted = !this.media.audioMuted;
			
			var stream:NetStream = this.connector.getBroadcastNetStream();
			
			if (this.media.audioMuted) 
				this.publisher.muteMicrophone(stream);
			else
				this.publisher.unmuteMicrophone(stream);
		}

		public function toggleFavorite():void
		{
			this.room.favorite = !this.room.favorite;
		}
		
		public function setCamera(value:Camera):void
		{
			if (!this.media) return;
			
			this.media.camera = value;
			
			var stream:NetStream = this.connector.getBroadcastNetStream();
			
			this.publisher.changeCamera(stream);
		}

		public function setMicrophone(value:Microphone):void
		{
			if (!this.media) return;
			
			this.media.microphone = value;
			
			var stream:NetStream = this.connector.getBroadcastNetStream();
			
			this.publisher.changeMicrophone(stream);
		}
		
		//----------------------------------------------------------------------
		//
		//	Methods
		//
		//----------------------------------------------------------------------
		
		private function subscribe(name:String):void
		{
			if (!this.room || !this.room.broadcasters) return;
			
			var n:uint = this.room.broadcasters.length;
			for (var i:uint = 0; i < n; i++)
			{
				var p:Broadcaster = 
					this.room.broadcasters.getItemAt(i) as Broadcaster;
				
				if (p.name == name)
					return;
			}
			
			var stream:NetStream = this.connector.getSubscribeNetStream();
			stream.bufferTime = 0.0;
			
			var broadcaster:Broadcaster = new Broadcaster();
			broadcaster.name = name;
			broadcaster.stream = stream;
			broadcaster.stream.play(name);
			
			this.room.broadcasters.addItem(broadcaster);
		}

		private function unsubscribe(name:String):void
		{
			if (!this.room || !this.room.broadcasters) return;
			
			var n:uint = this.room.broadcasters.length;
			for (var i:uint = 0; i < n; i++)
			{
				var b:Broadcaster = this.room.broadcasters.getItemAt(i) as Broadcaster;
				
				if (b && b.name == name)
				{
					b.stream.close();
					
					this.room.broadcasters.removeItemAt(i);
					
					return;
				}
			}
		}
		
		//----------------------------------------------------------------------
		//
		//	Handlers
		//
		//----------------------------------------------------------------------
		
		private function errorHandler(event:ErrorEvent):void
		{
			if (!this.room) return;
			
			this.room.connected = false;
			this.room.connecting = false;
		}
		
		
		private function connectHandler(event:Event):void
		{
			if (!this.room) return;
			
			this.room.connected = true;
			this.room.connecting = false;
			
			this.publish();
		}
		
		private function netStatusHandler(event:NetStatusEvent):void
		{
			switch (event.info.code)
			{
				// NetGroup
				
				case "NetGroup.MulticastStream.PublishNotify": // e.info.group
					
					this.subscribe(event.info.name);
					
					break;
				
				case "NetGroup.MulticastStream.UnpublishNotify": // e.info.group
					
					this.unsubscribe(event.info.name);
					
					break;
			}
			
		}
	}
}