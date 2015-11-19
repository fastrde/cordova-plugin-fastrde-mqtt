package de.fastr.cordova.plugin;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaResourceApi;

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

public class MQTTPlugin extends CordovaPlugin{

	private final String TAG = "MQTTPlugin";
	private MqttClient client;
	private MqttConnectOptions connOpts;
	private CallbackContext onConnectCallbackContext;

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);
    // your init code here
	}

	public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
		if (action.equals("connect")){
			String host = args.getString(0);
			int port = args.getInt(1);
			if (!port){
				port = 1883;
			}
			JSONObject options = args.getJSONObject(2);
			onConnectCallbackContext = callbackContext;
			connect(host, port, args);
			return true;
		}else if (action.equals("disconnect")){
			disconnect();
			return true;
		}else if (action.equals("publish")){
			String topic = args.getString(0);
			String msg = args.getString(1);
			int qos = args.getInt(2);
			boolean retained = args.getBoolean(3);
			publish(String topic, String msg, int qos, boolean retained);
			return true;
		}else if (action.equals("subscribe")){
			String topic = args.getString(0);
			int qos = args.getInt(1);
			subscribe(String topic, int qos);
			return true;
		}else if (action.equals("unsubscribe")){
			String topic = args.getString(0);
			unsubscribe(String topic);
			return true;
		}
		return false;
	}

	private void connect(String host, int port, JSONArray options){
		String clientId = "mqtt-client";
		String protocol = "tcp";
		if (options.has("ssl") && options.getBoolean("ssl")){
			protocol = "ssl";
		}
		if (options.has("clientId")) clientId = options.getString("clientId"); 

		client = new MqttClient(protocol + "://" + host + ":" + port, options.getString("clientId"));			
		connOpts = new MqttConnectOptions();	

		if (options.has("userName")) connOpts.setUserName(options.getString("userName"));
		if (options.has("password")) connOpts.setPassword(options.getString("password"));
		if (options.has("keepAliveInterval")) connOpts.setKeepAliveInterval(options.getInt("keepAliveInterval"));
		if (options.has("cleanSessionFlag")) connOpts.setCleanSession(options.getBoolean("cleanSession"));
		if (options.has("protocolLevel")) connOpts.setMqttVersion(options.getInt("protocolLevel"));

		if (options.has("will")){
			JSONObject will = options.getJSONObject("will");
			connOpts.setWill(options.getString("topic"), options.getString("message"), options.getInt("qos"), options.getBoolean("retain"));
		}
		Log.d(TAG, "connect "+host+":"+port);
		Log.d(TAG, "=================");
		Log.d(TAG, "clientId: " + client.getClientId());
		Log.d(TAG, "userName: " + connOpts.getUserName());
		Log.d(TAG, "password: " + connOpts.getPassword());
		Log.d(TAG, "keepAliveInterval: " + connOpts.getKeepAliveInterval());
		Log.d(TAG, "cleanSessionFlag: " + connOpts.isCleanSession()?"true":"false");
		Log.d(TAG, "protocolLevel: " + connOpts.getMqttVersion());
		Log.d(TAG, "ssl: " + if (protocol.equals("ssl")?"true":"false");
		client.connect(connOpts);
		onConnectCallbackContext.succhess(client.isConnected());
	}

	private void disconnect(){
		client.disconnect();
	}

	private void publish(String topic, String msg, int qos, boolean retained){
		client.publish(topic, msg, qos, retained);
	}

	private void subscribe(String topic, int qos){
		client.subscribe(topic, qos);
	}

	private void unsubscribe(String topic){
		client.unsubscribe(topic);
	}
}
