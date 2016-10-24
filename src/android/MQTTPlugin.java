package de.fastr.cordova.plugin;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.apache.cordova.CordovaResourceApi;
import org.apache.cordova.CordovaWebView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import java.math.BigInteger;

import android.net.Uri;
import android.util.Log;
import android.content.Context;

//import org.eclipse.paho.client.mqttv3.MqttAsyncClient;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttSecurityException;
import org.eclipse.paho.client.mqttv3.MqttTopic;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.eclipse.paho.client.mqttv3.MqttClientPersistence;
import org.eclipse.paho.client.mqttv3.persist.MqttDefaultFilePersistence;

public class MQTTPlugin extends CordovaPlugin implements MqttCallback{

  private final String TAG = "MQTTPlugin";
  //private MqttAsyncClient client;
  private MqttClient client;
  private MqttConnectOptions connOpts;
  private CallbackContext onConnectCallbackContext;
  private CallbackContext onDisconnectCallbackContext;
  //private CallbackContext onPublishCallbackContext;
  private CallbackContext onSubscribeCallbackContext;
  private CallbackContext onUnsubscribeCallbackContext;

  public void deliveryComplete(IMqttDeliveryToken token) { 
		JSONObject message = new JSONObject();
    final String jsonString = message.toString();
    final CordovaWebView webView_ = webView;
    cordova.getActivity().runOnUiThread(new Runnable() {
      public void run() {
        webView_.loadUrl(String.format("javascript:mqtt.onDelivered(%s);", jsonString));
      }   
    }); 
	}

  public void connectionLost(Throwable cause){ 
		JSONObject message = new JSONObject();
    final String jsonString = message.toString();
    final CordovaWebView webView_ = webView;
    cordova.getActivity().runOnUiThread(new Runnable() {
      public void run() {
        webView_.loadUrl(String.format("javascript:mqtt.onOffline(%s);", jsonString));
      }
    });
	}


  public void messageArrived(String topic, MqttMessage mqttMessage) throws Exception{
    JSONObject message = new JSONObject();
    message.put("topic", topic); 
    message.put("message", new String(mqttMessage.getPayload()));
    message.put("qos", mqttMessage.getQos());
    message.put("retain", mqttMessage.isRetained());
    final String jsonString = message.toString();
    final CordovaWebView webView_ = webView;
    cordova.getActivity().runOnUiThread(new Runnable() {
      public void run() {
        webView_.loadUrl(String.format("javascript:mqtt.onMessage(%s);", jsonString));
      }
    });
    Log.d(TAG, String.format("mqtt.onMessage(%s);", message.toString()));
  }


  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    //Connect
    if (action.equals("connect")){
      String host = args.getString(0);
      int port = 1883;
      if (args.length() > 1){
        port = args.getInt(1);
      }
      JSONObject options = null;
      if (args.length() > 2){
        options = args.getJSONObject(2);
      }else{
        options = new JSONObject();
      }
			Log.d(TAG, "" + host + " : " + port);
      connect(host, port, options, callbackContext);
      return true;

    //Disconnect
    }else if (action.equals("disconnect")){
      disconnect(callbackContext);
      return true;

    //Publish
    }else if (action.equals("publish")){
      Integer id = args.optInt(0);
      String topic = args.getString(1);
      String msg = args.getString(2);
      int qos = args.getInt(3);
      boolean retained = args.getBoolean(4);
      publish(id, topic, msg, qos, retained, callbackContext);
      return true;

    //Subscribe
    }else if (action.equals("subscribe")){
      String topic = args.getString(0);
      int qos = args.getInt(1);
      subscribe(topic, qos, callbackContext);
      return true;

    //Unsubscribe
    }else if (action.equals("unsubscribe")){
      String topic = args.getString(0);
      unsubscribe(topic, callbackContext);
      return true;
    }
    return false;
  }

  private void connect(final String host, final int port, final JSONObject options, final CallbackContext callbackContext){
    final Context context = cordova.getActivity().getApplicationContext(); 
    final MQTTPlugin self = this;

    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        String clientId = "mqtt-client";
        String protocol = "tcp";
        try{
          if (options.has("ssl") && options.getBoolean("ssl")){
            protocol = "ssl";
          }
          if (options.has("clientId")) clientId = options.getString("clientId"); 
          MqttClientPersistence persistence = new MqttDefaultFilePersistence(context.getApplicationInfo().dataDir);  

          //client = new MqttAsyncClient(protocol + "://" + host + ":" + port, options.getString("clientId"), persistence);      
          client = new MqttClient(protocol + "://" + host + ":" + port, options.getString("clientId"), persistence);      
          connOpts = new MqttConnectOptions();  

          if (options.has("username")) connOpts.setUserName(options.getString("username"));
          if (options.has("password")) connOpts.setPassword(options.getString("password").toCharArray());
          if (options.has("keepAlive")) connOpts.setKeepAliveInterval(options.getInt("keepAlive"));
          if (options.has("cleanSession")) connOpts.setCleanSession(options.getBoolean("cleanSession"));
          if (options.has("protocol")) connOpts.setMqttVersion(options.getInt("protocol"));

          if (options.has("will")){
            JSONObject will = options.getJSONObject("will");
            connOpts.setWill(options.getString("topic"), options.getString("message").getBytes(), options.getInt("qos"), options.getBoolean("retain"));
          }
          Log.d(TAG, "connect "+host+":"+port);
          Log.d(TAG, "=================");
          Log.d(TAG, "clientId: " + client.getClientId());
          Log.d(TAG, "userName: " + connOpts.getUserName());
          Log.d(TAG, "password: " + connOpts.getPassword());
          Log.d(TAG, "keepAliveInterval: " + connOpts.getKeepAliveInterval());
          Log.d(TAG, "cleanSessionFlag: " + (connOpts.isCleanSession()?"true":"false"));
          Log.d(TAG, "protocolLevel: " + connOpts.getMqttVersion());
          Log.d(TAG, "ssl: " + (protocol.equals("ssl")?"true":"false"));
          client.connect(connOpts);

          client.setCallback((MqttCallback) self);  
         	JSONObject ret = new JSONObject();
					ret.put("status", client.isConnected()?1:0);
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, ret));
        }catch(JSONException e){
          Log.d(TAG, "Exception", e);
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, e.getMessage()));
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, e.getMessage()));
        }
      }
    });
  }

 
  private void disconnect(final CallbackContext callbackContext){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.disconnect();
         	JSONObject ret = new JSONObject();
					ret.put("status", client.isConnected()?1:0);
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, ret));
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, e.getMessage()));
       	}catch(JSONException jsonException){
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, jsonException.getMessage()));
        }catch(Exception e){
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, e.getMessage()));
				}
      }
    });
  }

 
  private void publish(final Integer id, final String topic, final String msg, final int qos, final boolean retained, final CallbackContext callbackContext){
		Log.d(TAG, "publish " + topic + " | " + msg);
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.publish(topic, msg.getBytes(), qos, retained);
         	JSONObject ret = new JSONObject();
					if (id != null){
					  ret.put("cacheId", id);
					}
					ret.put("topic", topic);
					ret.put("message", msg);
					ret.put("qos", qos);
					ret.put("retain", retained);
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, ret));
       	}catch(JSONException jsonException){
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, jsonException.getMessage()));
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
					try{
          	JSONObject err = new JSONObject();
						err.put("id", id);
						err.put("error", e.getMessage());
          	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, err));
        	}catch(JSONException jsonException){
          	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, jsonException.getMessage()));
					}
				}
      }
    });
  }


  private void subscribe(final String topic, final int qos, final CallbackContext callbackContext){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.subscribe(topic, qos);
         	JSONObject ret = new JSONObject();
					ret.put("topic", topic);
					ret.put("qos", qos);
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, ret));
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, e.getMessage()));
       	}catch(JSONException jsonException){
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, jsonException.getMessage()));
        }
			}
    });
  }


  private void unsubscribe(final String topic, final CallbackContext callbackContext){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.unsubscribe(topic);
         	JSONObject ret = new JSONObject();
					ret.put("topic", topic);
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, ret));
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
          callbackContext.error(e.getMessage());
       	}catch(JSONException jsonException){
         	callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, jsonException.getMessage()));
        }
      }
    });
  }
}
