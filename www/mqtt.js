var mqtt = {
	/**
   * Paho MQTT client
   */
	client: null,
  /**
   *  @param {string} wsuri - full websocket uri with port and path for example ws://mymqttserver.io:8888/mqtt
   */ 
	init: function(wsuri, clientId){
		mqtt.client = new Paho.MQTT.Client(wsuri, clientId);
	},
	connect: function(connectOptions){
		mqtt.client.connect(connectOptions);
	},
	disconnect: function(){
		mqtt.client.disconnect();
	},
	getTraceLog: function(){
		return mqtt.client.getTraceLog();
	},
	send: function(message){
		mqtt.client.send(message);
	},
	startTrace: function(){
		mqtt.client.startTrace();
	},
	stopTrace: function(){
		mqtt.client.stopTrace();
	},
	subscribe: function(filter, subscribeOptions){
		mqtt.client.subscribe(filter, subscribeOptions);
	},
	unsubscribe: function(filter, unsubscribeOptions){
	 	mqtt.client.unsubscribe(filter, unsubscribeOptions);
	},
  createMessage: function(destination, payload, qos, retained){
		var message = new Paho.MQTT.Message(payload);
		message.destinationName = destination;
		message.qos = qos || 0;
		message.retained = retained || false;
		return message;
	},
	setOnMessageArrived: function(func){
		mqtt.client.onMessageArrived = func;
	},
	setOnConnectionLost: function(func){
		mqtt.client.onConnectionLost = func;
	}
};

module.exports = mqtt;
