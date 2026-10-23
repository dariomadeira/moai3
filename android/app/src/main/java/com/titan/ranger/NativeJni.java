package com.titan.ranger;

import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;
import com.google.gson.Gson;
import com.titan.ranger.bean.RangerResult;
import org.json.JSONObject;
import java.util.HashMap;

public class NativeJni {
    private static final String TAG = "NativeJni";
    public static String f11430d = "";
    private static volatile NativeJni instance;

    private HandlerThread handlerThread;
    private Handler handler;
    private static final Gson gson = new Gson();

    static {
        try {
            Log.i(TAG, "Loading libranger-jni...");
            System.loadLibrary("c++_shared");
            System.loadLibrary("ranger-jni");
            Log.i(TAG, "Successfully loaded libc++_shared and libranger-jni (JNI_OnLoad done)");
        } catch (Throwable th) {
            Log.e(TAG, "Error loading native ranger libraries: " + th.getMessage(), th);
        }
    }

    private NativeJni() {
        handlerThread = new HandlerThread("handlerRanger");
        handlerThread.start();
        handler = new Handler(handlerThread.getLooper());
    }

    public static NativeJni c() {
        if (instance == null) {
            synchronized (NativeJni.class) {
                if (instance == null) {
                    instance = new NativeJni();
                }
            }
        }
        return instance;
    }

    // Single native C++ entrypoint
    private native String Call(String cmd, String jsonArgs);

    public String callDirect(String cmd, String jsonArgs) {
        try {
            return Call(cmd, jsonArgs);
        } catch (Throwable th) {
            Log.e(TAG, "callDirect error cmd=" + cmd + ": " + th.getMessage(), th);
            return "{\"err\": -1, \"res\": \"\"}";
        }
    }

    public void initWorkPath(String workPath) {
        handler.post(() -> {
            try {
                HashMap<String, String> map = new HashMap<>();
                map.put("work_path", workPath);
                String res = callDirect("Init", gson.toJson(map));
                Log.i(TAG, "Init workPath response: " + res);
            } catch (Exception e) {
                Log.e(TAG, "initWorkPath error: " + e.getMessage(), e);
            }
        });
    }

    public void getVersion() {
        handler.post(() -> {
            try {
                String res = callDirect("GetVersion", "{}");
                Log.i(TAG, "GetVersion response: " + res);
            } catch (Exception e) {
                Log.e(TAG, "getVersion error: " + e.getMessage(), e);
            }
        });
    }

    public void setEnv(String jsonEnv) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("env", jsonEnv);
                String payload = obj.toString();
                Log.i(TAG, "SetEnv dispatched: " + payload);
                String res = callDirect("SetEnv", payload);
                Log.i(TAG, "SetEnv response: " + res);
            } catch (Exception e) {
                Log.e(TAG, "setEnv error: " + e.getMessage(), e);
            }
        });
    }

    public void setEntries(String jsonEntries) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("entries", jsonEntries);
                String payload = obj.toString();
                Log.i(TAG, "SetEntries dispatched: " + payload);
                String res = callDirect("SetEntries", payload);
                Log.i(TAG, "SetEntries response: " + res);
            } catch (Exception e) {
                Log.e(TAG, "setEntries error: " + e.getMessage(), e);
            }
        });
    }

    public void setPlayer(int instanceId, String player, int err) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("player", player);
                obj.put("err", err);
                String res = callDirect("SetPlayer", obj.toString());
                Log.i(TAG, "SetPlayer response: " + res);
            } catch (Exception e) {
                Log.e(TAG, "setPlayer error: " + e.getMessage(), e);
            }
        });
    }

    public void prepareProgram(int instanceId, String name, String jsonProgram, String extra) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("name", name);
                obj.put("program", jsonProgram);
                obj.put("extra", extra != null ? extra : "");
                String res = callDirect("PrepareProgram", obj.toString());
                Log.i(TAG, "PrepareProgram response: " + res);
            } catch (Exception e) {
                Log.e(TAG, "prepareProgram error: " + e.getMessage(), e);
            }
        });
    }

    public void stopProgram(int instanceId, String name) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("name", name);
                callDirect("StopProgram", obj.toString());
            } catch (Exception e) {
                Log.e(TAG, "stopProgram error: " + e.getMessage(), e);
            }
        });
    }
}
