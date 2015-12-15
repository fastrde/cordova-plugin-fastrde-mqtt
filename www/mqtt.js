var mqtt={
  host: null,
  port: null,
  qos: null,
  clientId: null,
  username: null,
  password: null,
  ssl: null,
  keepAlive: null,
  timeout: null,
  cleanSession: null,
  protocol: null, 
  will: null,
  cache: null,
  init: function(options){
    mqtt.host = required(options.host);      
    mqtt.port = optional(options.port, 1883);      
    mqtt.options = {
      qos  : optional(options.qos, 0),
      clientId : optional(options.clientId, 'cordova_mqtt_' + Math.random().toString(16).substr(2, 8)),      
      username : optional(options.username, null),
      password : optional(options.password, null),
      ssl : optional(options.ssl, false),
      keepAlive : optional(options.keepAlive, 10),
      timeout : optional(options.timeout, 30),
      cleanSession : optional(options.cleanSession, true),
      protocol : optional(options.protocol, 4)
    };
    mqtt.offlineCaching = optional(options.offlineCaching, true);

    if (mqtt.offlineCaching){
      mqtt.cache = window.sqlitePlugin.openDatabase({name: "mqttcache.db", location: 2}, 
        function(db) {
          db.transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS cache(id INTEGER PRIMARY KEY AUTOINCREMENT, topic TEXT, message INT, qos INT, retain INT)",[], 
              function(){
                console.log("Created");
              },
              function(){
                console.log("Creation Error");
              });
          }, function (error) {
            console.error("Something went wrong: " + error);
          });
        }, 
        function(err) {
          console.error('Open database ERROR: ' + JSON.stringify(err));
        }
      );
    }
  },

  will: function(message){
    mqtt.will = {
      topic: required(message.topic),
      message: required(message.message),
      qos: required(message.qos),
      retain: required(message.retain)
    };
  },
  
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
  connect: function(){
    if (mqtt.host == null){
      console.error("You have to call init before you connect");
      return;
    }
    cordova.exec(
      function(success){
        console.log("js connected success");
        mqtt.onConnect();
      }, 
      function(err) {
        mqtt.onConnectError();
      }, 
      "MQTTPlugin", "connect", [mqtt.host, mqtt.port, mqtt.options]);
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
    console.log("js publish");

    if (mqtt.offlineCaching && mqtt.cache != null){
      mqtt.cache.transaction(function(tx){
        tx.executeSql("INSERT INTO cache(topic, message, qos, retain) VALUES(?,?,?,?)", [topic, message, qos, retain], 
          function(tx, res){
						mqtt.publishCached(tx);
          }, 
          function(err){
            console.log("js INSERT error");
          
          }
        );
      }, function(error){
				 console.log("js INSERT TRANSACTION error" + error);
			});    
    }else{
      mqtt._publish(topic, message, qos, retain,
        function(success){
          console.log("js publish direct success");
          mqtt.onPublish(success, null);
        }, 
        function(err) {
          console.log("js publish error");
          mqtt.onPublishError(err, null);
        }
      ); 
    }
  },

  publishCached: function(tx){
		console.log("publishCached");
    tx.executeSql("SELECT * FROM cache ORDER BY id", [], 
      function selectSuccess(tx, res){
				console.log("Selected items " + res.rows.length);
        for (var i = 0; i < res.rows.length; i++){
					console.log(i);
          var message = res.rows.item(i);
          mqtt._publish(message.topic, message.message, message.qos, message.retain, 
            function publishSuccess(success){
              console.log("js publish success " + message.id);
              	tx.executeSql("DELETE FROM cache WHERE id = ?", [message.id],
                	function deleteSuccess(tx, res){
               	   	console.log("DELETED " + res.row.item(0).id);
                	},
                	function deleteError(err){
               	   	console.log("Delete Error: "+ err);
                	}
              	);
              	mqtt.onPublish(success, message.id);  
						}, 
            function publishError(error){
             	console.log("js publish error");
             	mqtt.onPublishError(error, message.id);
           	}
         	);
        }      
      },
      function selectError(err){
        console.log("js SELECT error");
      }
    );
  },

  _publish: function(topic, message, qos, retain, success, error){
      cordova.exec(success, error, "MQTTPlugin", "publish", [topic, message, qos, retain]);
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


  onConnect: function(){ 
    console.log("onConnect");
  },
  onConnectError: function(){ 
    console.error("onConnectError");
  },
  onDisconnect: function(){ 
    console.log("onDisconnect");
  },
  onDisconnectError: function(){ 
    console.log("onDisconnectError");
  },
  onPublish: function(message, cacheId){ 
    console.log("onPublish " + cacheId);
  },
  onPublishError: function(){ 
    console.log("onPublishError");
  },
  onSubscribe: function(){ 
    console.log("onSubscribe");
  },
  onSubscribeError: function(){ 
    console.log("onSubscribeError");
  },
  onUnsubscribe: function(){ 
    console.log("onUnsubscribe");
  },
  onUnsubscribeError: function(){ 
    console.log("onUnsubscribeError");
  },
  onMessage: function(topic, message, packet){ 
    console.log("onMessage");
  },
  onMessageError: function(topic, message, packet){ 
    console.log("onMessageError");
  },

  //onReconnect: function(){ },
  //onClose: function(){ },
  onOffline: function(){ 
    console.log("onOffline");
  },
  onError: function(){ 
    console.log("onError");  
  }
}

function optional(obj, def){
  return (isset(obj))  ? obj : def;
}

function required(obj){
  if (!isset(obj)){
    console.error(key + " is required but not set");
  }
  return obj;
}

function isset(obj){
  return (typeof obj != 'undefined'); 
}
module.exports = mqtt;
