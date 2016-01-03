var mqtt={
	debug_deleteTable: true,
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
	reconnectInterval: 5,
	cacheSendInterval: 10,
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
					db.executeSql("PRAGMA synchronous=OFF", [], function(){
					}, function(error){
						console.log("PRAGMA error: ",error);
						return false;								
					});
					if (mqtt.debug_deleteTable){	
          	db.transaction(function (tx) {
            	tx.executeSql("DROP TABLE cache;");
							mqtt.debug_deleteTable = false;
						});
					}
          db.transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS cache(id INTEGER PRIMARY KEY AUTOINCREMENT, topic TEXT, message INT, qos INT, retain INT, sending INT)",[], 
              function createSuccess(tx, res){
                console.log("Created");
								document.addEventListener("online", mqtt.onOnline, false);
								document.addEventListener("offline", mqtt.onOffline, false);
								if (!mqtt.isOnline()){
									mqtt._reconnect();
								}
								mqtt.onInit();			
              },
              function createError(){
                console.log("Creation Error");
								mqtt.onInitError();			
								return false;
              });
          }, 
					function transactionError(error) {
            console.error("Something went wrong: " + JSON.stringify(error));
						mqtt.onInitError();			
						return false;
          });
        }, 
        function openDBError(err) {
          console.error('Open database ERROR: ' + JSON.stringify(err));
					mqtt.onInitError();			
					return false;
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
      case 'init':
        mqtt.onInit = optional(success, function(){console.log("success");});
        mqtt.onInitError = optional(fail, function(){console.log("fail");});
      break;
      case 'connect':
        mqtt.onConnect = optional(success, function(){console.log("success");});
        mqtt.onConnectError = optional(fail, function(){console.log("fail");});
      break;
      case 'disconnect':
        mqtt.onDisconnect = optional(success, function(){console.log("success");});
        mqtt.onDisconnectError = optional(fail, function(){console.log("fail");});
      break;
      case 'reconnect':
        mqtt.onReconnect = optional(success, function(){console.log("success");});
        mqtt.onReconnectError = optional(fail, function(){console.log("fail");});
      break;
      case 'publish':
        mqtt.onPublish = optional(success, function(){console.log("success");});
        mqtt.onPublishError = optional(fail, function(){console.log("fail");});
      break;
      case 'subscribe':
        mqtt.onSubscribe = optional(success, function(){console.log("success");});
        mqtt.onSubscribeError = optional(fail, function(){console.log("fail");});
      break;
      case 'unsubscribe':
        mqtt.onUnsubscribe = optional(success, function(){console.log("success");});
        mqtt.onUnsubscribeError = optional(fail, function(){console.log("fail");});
      break;
      case 'message':
        mqtt.onMessage = optional(success, function(){console.log("success");});
			break;
			case 'delivered':
        mqtt.onDelivered = optional(success, function(){console.log("delivered");});
			break;
			case 'offline':
        mqtt.onOffline = optional(success, function(){console.log("offline");});
			break;
    }
  },

	connect: function(){
    if (mqtt.host == null){
      console.error("You have to call init before you connect");
      return;
    }
		mqtt._connect(
      function(success){
        console.log("Connected.");
				mqtt._resendCached();
        mqtt.onConnect();
      }, 
      function(err) {
        mqtt.onConnectError();
      } 
		)
	},

  _connect: function(success, error){
    cordova.exec(success, error, "MQTTPlugin", "connect", [mqtt.host, mqtt.port, mqtt.options]);
  },

	_reconnect: function(){
		mqtt.disconnect();
		console.log("Trying to Reconnect...");
		mqtt._connect(
			function connectSuccess(){
				console.log("(re)Connected Again");
				mqtt._resendCached();
				mqtt.onReconnect();
			},
			function connectError(){
				console.log("Next try in " + mqtt.reconnectInterval + " seconds.");
				setTimeout(mqtt.onOffline, mqtt.reconnectInterval * 1000);
				mqtt.onReconnectError();
			}
		);
	},

  disconnect: function(){
    cordova.exec(
      function(success){
        console.log("Disconnected.");
        mqtt.onDisconnect();
      }, 
      function(err) {
        mqtt.onDisconnectError();
      }, 
      "MQTTPlugin", "disconnect", []);
  },

  publish: function(options, success, fail){ 
		success = success || function(){};
		fail = fail || function(){};
    var topic = (isset(options.topic)) ? options.topic : "public";  
    var message = (isset(options.message)) ? options.message : "";  
    var qos = (isset(options.qos)) ? options.qos : 0;  
    var retain = (isset(options.retain)) ? options.retain : false;  

    if (mqtt.offlineCaching && mqtt.cache != null){
    	console.log("Cache Publishing " + message);
      mqtt.cache.transaction(function(tx){
        tx.executeSql("INSERT INTO cache(topic, message, qos, retain, sending) VALUES(?,?,?,?,?)", [topic, message, qos, retain,0], 
          function insertSuccess(tx, res){
						mqtt._publishCached(tx);
          }, 
          function insertError(tx, err){
            console.log("Caching failed: ", err);
						return false;
          }
        );
      }, 
			function transactionError(err){
        console.log("Caching failed: ", err);
				return false;	
			});    
    }else{
    	console.log("Direct Publishing " + message);
      mqtt._publish(null, topic, message, qos, retain,
        function(message){
					mqtt.onPublish(message);
					success(message);
        }, 
        function(err) {
          console.log("direct publishing failed: ", err);
          mqtt.onPublishError(err, null);
					fail(err);
        }
      ); 
    }
  },

	_resendCached: function(){
		if (mqtt.offlineCaching){
			mqtt.cache.transaction(function(tx){mqtt._publishCached(tx)});
		}
	},

  _publishCached: function(tx){
    tx.executeSql("SELECT * FROM cache WHERE sending = 0 ORDER BY id", [], 
      function selectSuccess(tx, res){
				console.log("Found "+res.rows.length+" cached Messages");
        for (var i = 0; i < res.rows.length; i++){
					(function(i, tx){
          var message = res.rows.item(i);
					console.log("Publishing: " + message.id +"| Topic:"+ message.topic +"| Message:"+ message.message +"| QOS:"+ message.qos +"| Retain:"+ message.retain);
					tx.executeSql("UPDATE cache SET sending = 1 WHERE id = ?", [message.id],
						function updateSuccess(tx, res){
							console.log("locked Message " + message.id);
          		mqtt._publish(message.id, message.topic, message.message, message.qos, message.retain, 

		            function publishSuccess(message){
									var id = message.cacheId;
		              console.log("Message " + id + " published");
									mqtt.cache.transaction(
										function(tx){
 		  	     	     		console.log("Deleting Message " + id + " from cache");
  		       	    		tx.executeSql("DELETE FROM cache WHERE id = ?", [id],
        	  		     		function deleteSuccess(tx, res){
        		 	    				console.log("Deleted Message " + id + " from cache");
   	      	   		   		},
   		      	      		function deleteError(err){
    		     	     	   		console.error("Could not delete Message. Error: "+ err);
													return false;	
      		   	      		}
         			    		);
										},
										function transactionError(error){
											console.error("js INSERT TRANSACTION error: " + error);
											return false;	
										}
									);    
									delete(message.cacheId);
									mqtt.onPublish(message);
							  }, 
            	  function publishError(result){
             		  console.log("publishing failed : " + result.id );
									mqtt.cache.transaction(
										function(tx){
             		  		console.log("resetting lock on " + result.id );
											tx.executeSql("UPDATE cache SET sending = 0 WHERE id = ?", [result.id], function(tx, res){
             		  			console.log("lock resetted on " + result.id );
											}, function(error){
             		  			console.log("lock NOT resetted on " + result.id );
												return false;	
											});
										}
									);	
             		  mqtt.onPublishError(result.error, result.id);
           		  }
         		  );
					  },
					  function updateError(error){
           	  console.error("js update error: " + error);
				 	  }
          );
					})(i, tx);
        } 
      },
      function selectError(err){
        console.log("js SELECT error: " + err);
				return false;	
      }
    );
  },

  _publish: function(id, topic, message, qos, retain, success, error){
      cordova.exec(success, error, "MQTTPlugin", "publish", [id, topic, message, qos, retain]);
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

  onInit: function(){ 
    console.log("onInit");
  },
  onInitError: function(){ 
    console.error("onInitError");
  },

  onConnect: function(){ 
    console.log("onConnect");
  },
  onConnectError: function(){ 
    console.error("onConnectError");
  },

  onReconnect: function(){ 
    console.log("onReconnect");
  },
  onReconnectError: function(){ 
    console.error("onReconnectError");
  },

  onDisconnect: function(){ 
    console.log("onDisconnect");
  },
  onDisconnectError: function(){ 
    console.log("onDisconnectError");
  },

  onPublish: function(cacheId){ 
    console.log("onPublish " + cacheId);
  },
  onPublishError: function(error, id){ 
    console.log("onPublishError " + id + ": ", error );
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

  onDelivered: function(){ 
    console.log("onDelivered");
  },

  onOnline: function(){ 
		console.log("Hi i am online");
  },
  onOffline: function(){ 
		mqtt._reconnect();
  },

  onError: function(){ 
    console.log("onError");  
  },

	showCache: function(){
		mqtt.cache.readTransaction(function(tx){
    	tx.executeSql("SELECT * FROM cache ORDER BY id", [], 
				function(tx, res){
					console.log("BEGIN");
        	for (var i = 0; i < res.rows.length; i++){
						//(function(i, tx){
          	var message = res.rows.item(i);
						console.log(message.id +" | "+ message.topic +" | "+ message.message +" | "+ message.qos +" | "+ message.retain + " | " + message.sending);
					} 
					console.log("END");
				}
			);
		});
	},
	isOnline: function(){
		var states = {};
    states[Connection.UNKNOWN]  = 'Unknown connection';
    states[Connection.ETHERNET] = 'Ethernet connection';
    states[Connection.WIFI]     = 'WiFi connection';
    states[Connection.CELL_2G]  = 'Cell 2G connection';
    states[Connection.CELL_3G]  = 'Cell 3G connection';
    states[Connection.CELL_4G]  = 'Cell 4G connection';
    states[Connection.CELL]     = 'Cell generic connection';
    states[Connection.NONE]     = 'No network connection';
		console.log("Network Connection is: "+ states[navigator.connection.type]);
		return (navigator.connection.type != Connection.NONE);
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
