var mqtt={
	keepAliveInterval: 10,
	clientId: 'cordova_mqtt_' + Math.random().toString(16).substr(2, 8),
	protocolLevel: 4,
	cleanSessionFlag: true,
	userName: null,
	password: null,
	connectTimeout: 30,
	will: null/*{
		topic: null,
		message: null,
		retain: null
		qos: 0
	}*/,	
	on: function(evt, success, fail){
		switch(evt){
			case 'connect':
				mqtt.onConnect = success;
				mqtt.onConnectError = fail;
			break;
			case 'disconnect':
				mqtt.onDisconnect = success;
				mqtt.onDisconnectError = fail;
			break;
			case 'publish':
				mqtt.onPublish = success;
				mqtt.onPublishError = fail;
			break;
			case 'subscribe':
				mqtt.onSubscribe = success;
				mqtt.onSubscribeError = fail;
			break;
			case 'unsubscribe':
				mqtt.onUnsubscribe = success;
				mqtt.onUnsubscribeError = fail;
			break;
			case 'message':
				mqtt.onMessage = success;
				mqtt.onMessageError = fail;
		}
	},
	connect: function(options){
		var host = (isset(options.host)) ? options.host : "";	
		var port = (isset(options.port)) ? options.port : 1883; 
		var clientId = (isset(options.clientId)) ? options.clientId : mqtt.clientId;
		cordova.exec(
			function(success){
				console.log("js connected success");
				mqtt.onConnect();
			}, 
			function(err) {
				mqtt.onConnectError();
      }, 
			"MQTTPlugin", "connect", [host, port, options]);
	},
	disconnect: function(){
		cordova.exec(
			function(success){
				console.log("js disconnected success");
				mqtt.onDisconnect();
			}, 
			function(err) {
				console.log("js disconnected error");
				mqtt.onDisconnectError();
      }, 
			"MQTTPlugin", "disconnect", []);
	},
	publish: function(options){ //topic, payload, qos, retained){
		var topic = (isset(options.topic)) ? options.topic : "public";	
		var message = (isset(options.message)) ? options.message : "";	
		var qos = (isset(options.qos)) ? options.qos : 0;	
		var retain = (isset(options.retain)) ? options.retain : false;	
		var cacheId = (isset(options.cacheId)) ? options.cacheId : null;
		console.log("js publish");
		cordova.exec(
			function(success){
				console.log("js publish success");
				mqtt.onPublish(success, cacheId);
			}, 
			function(err) {
				console.log("js publish error");
				mqtt.onPublishError(err, cacheId);
      }, 
			"MQTTPlugin", "publish", [topic, message, qos, retain]);
	},
	subscribe: function(options){ //topic, qos){
		var topic = (isset(options.topic)) ? options.topic : "public";	
		var qos = (isset(options.qos)) ? options.qos : 0;	
		console.log("js subscribe");
		cordova.exec(
			function(success){
				console.log("js subscribe success");
				mqtt.onSubscribe();
			}, 
			function(err) {
				console.log("js subscribe error");
				mqtt.onSubscribeError();
      }, 
			"MQTTPlugin", "subscribe", [topic, qos]);
	},
	unsubscribe: function (options){ //topic){
		var topic = (isset(options.topic)) ? options.topic : "public";	
		cordova.exec(
			function(success){
				console.log("js unsubscribe success");
				mqtt.onUnsubscribe();
			}, 
			function(err) {
				console.log("js unsubscribe error");
				mqtt.onUnsubscribeError();
      }, 
			"MQTTPlugin", "unsubscribe", [topic]);
	},


	onConnect: function(){ },
	onConnectError: function(){ },
	onDisconnect: function(){ },
	onDisconnectError: function(){ },
	onPublish: function(){ },
	onPublishError: function(){ },
	onSubscribe: function(){ },
	onSubscribeError: function(){ },
	onUnsubscribe: function(){ },
	onUnsubscribeError: function(){ },
	onMessage: function(topic, message, packet){ },
	onMessageError: function(topic, message, packet){ },

	onReconnect: function(){ },
	onClose: function(){ },
	onOffline: function(){ },
	onError: function(){ },
	onDelivered: function(){ }
}

function isset(obj){
	return (typeof obj != 'undefined'); 
}
module.exports = mqtt;
