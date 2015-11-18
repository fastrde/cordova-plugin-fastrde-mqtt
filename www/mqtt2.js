var mqtt={
	keepalive: 10,
	clientId: 'cordova_mqtt_' + Math.random().toString(16).substr(2, 8),
	protocolVersion: 4,
	clean: true,
	reconnectPeriod: 1,
	connectTimeout: 30,
	username: null,
	password: null,
	will: null/*{
		topic: null,
		message: null,
		retain: null
		qos: 0
	}*/,	
	connect: function(host, port, options){
		options = options || {};
		options.ssl = options.ssl || false;
	},
	disconnect: function(){
	},
	publish: function(topic, payload, qos, retained){
	},
	subscribe: function(topic, qos){
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

