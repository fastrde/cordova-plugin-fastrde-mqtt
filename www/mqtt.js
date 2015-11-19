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
	on: function(evt, func){
		switch(evt){
			case 'connect':
				mqtt.onConnect = func;
			break;
			case 'message':
				mqtt.onMessage = func;
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
      }, 
			"MQTTPlugin", "connect", [host, port, options]);
	},
	disconnect: function(){
	},
	publish: function(options){ //topic, payload, qos, retained){
		var topic = (isset(options.topic)) ? options.topic : "public";	
		var message = (isset(options.message)) ? options.message : "";	
		var qos = (isset(options.qos)) ? options.qos : 0;	
		var retain = (isset(options.retain)) ? options.retain : false;	
		console.log("js publish");
		cordova.exec(
			function(success){
				console.log("js publish success");
			}, 
			function(err) {
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
			}, 
			function(err) {
      }, 
			"MQTTPlugin", "subscribe", [topic, qos]);
	},
	unsubscribe: function (topic){
	},
	onConnect: function(){
	},
	onReconnect: function(){
	},
	onClose: function(){
	},
	onOffline: function(){
	},
	onError: function(){
	},
	onMessage: function(topic, message, packet){
	}
}

function isset(obj){
	return (typeof obj != 'undefined'); 
}
module.exports = mqtt;
