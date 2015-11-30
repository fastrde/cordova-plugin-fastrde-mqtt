package de.fastr.cordova.plugin;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
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
  private MqttClient client;
  private MqttConnectOptions connOpts;
  private CallbackContext onConnectCallbackContext;
  private CallbackContext onDisconnectCallbackContext;
  private CallbackContext onPublishCallbackContext;
  private CallbackContext onSubscribeCallbackContext;
  private CallbackContext onUnsubscribeCallbackContext;

  public void deliveryComplete(IMqttDeliveryToken token) { }

  public void connectionLost(Throwable cause){ }


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
      onConnectCallbackContext = callbackContext;
      connect(host, port, options);
      return true;

    //Disconnect
    }else if (action.equals("disconnect")){
      onDisconnectCallbackContext = callbackContext;
      disconnect();
      return true;

    //Publish
    }else if (action.equals("publish")){
      onPublishCallbackContext = callbackContext;
      String topic = args.getString(0);
      String msg = args.getString(1);
      int qos = args.getInt(2);
      boolean retained = args.getBoolean(3);
      publish(topic, msg, qos, retained);
      return true;

    //Subscribe
    }else if (action.equals("subscribe")){
      onSubscribeCallbackContext = callbackContext;
      String topic = args.getString(0);
      int qos = args.getInt(1);
      subscribe(topic, qos);
      return true;

    //Unsubscribe
    }else if (action.equals("unsubscribe")){
      onUnsubscribeCallbackContext = callbackContext;
      String topic = args.getString(0);
      unsubscribe(topic);
      return true;
    }
    return false;
  }


  private void connect(final String host, final int port, final JSONObject options){
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

          client = new MqttClient(protocol + "://" + host + ":" + port, options.getString("clientId"), persistence);      
          connOpts = new MqttConnectOptions();  

          if (options.has("userName")) connOpts.setUserName(options.getString("userName"));
          if (options.has("password")) connOpts.setPassword(options.getString("password").toCharArray());
          if (options.has("keepAliveInterval")) connOpts.setKeepAliveInterval(options.getInt("keepAliveInterval"));
          if (options.has("cleanSessionFlag")) connOpts.setCleanSession(options.getBoolean("cleanSessionFlag"));
          if (options.has("protocolLevel")) connOpts.setMqttVersion(options.getInt("protocolLevel"));

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
          onConnectCallbackContext.success((client.isConnected()?1:0));
        }catch(JSONException e){
          Log.d(TAG, "Exception", e);
          onConnectCallbackContext.error(e.getMessage());
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
          onConnectCallbackContext.error(e.getMessage());
        }
      }
    });
  }

 
  private void disconnect(){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.disconnect();
          onDisconnectCallbackContext.success(((!client.isConnected())?1:0));
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
          onDisconnectCallbackContext.error(e.getMessage());
        }
      }
    });
  }

 
  private void publish(final String topic, final String msg, final int qos, final boolean retained){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.publish(topic, msg.getBytes(), qos, retained);
          onPublishCallbackContext.success(msg.getBytes());
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
          onPublishCallbackContext.error(e.getMessage());
        }
      }
    });
  }


  private void subscribe(final String topic, final int qos){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.subscribe(topic, qos);
          onSubscribeCallbackContext.success();
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
          onSubscribeCallbackContext.error(e.getMessage());
        }
      }
    });
  }


  private void unsubscribe(final String topic){
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try{
          client.unsubscribe(topic);
          onUnsubscribeCallbackContext.success();
        }catch(MqttException e){
          Log.d(TAG, "Exception", e);
          Log.d(TAG, e.getMessage());
          onUnsubscribeCallbackContext.error(e.getMessage());
        }
      }
    });
  }
}
