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

    /**
     * Salto: Ranger empieza a bajar desde [momentMs] (como la app oficial,
     * C7707e.m29665B0 → NativeJni "Seek"). Recién cuando termina
     * ([onDone]) el reproductor puede saltar; si no, el tramo da 404.
     */
    public void seek(int instanceId, String name, long momentMs, Runnable onDone) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("name", name);
                obj.put("moment", momentMs);
                obj.put("offset", -1L);
                String res = callDirect("Seek", obj.toString());
                Log.i(TAG, "Seek " + momentMs + " -> " + res);
            } catch (Exception e) {
                Log.e(TAG, "seek error: " + e.getMessage(), e);
            }
            if (onDone != null) onDone.run();
        });
    }

    // Avisos del reproductor a Ranger, como la app oficial (C7707e): sin
    // ellos Ranger baja el video en orden y un salto lejos responde 404.

    /** Operación del reproductor: "start", "pause", "seekTo", "stop". */
    public void onPlayerOperation(int instanceId, String operation, String data) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("operation", operation);
                obj.put("data", data != null ? data : "");
                obj.put("err", 0);
                String res = callDirect("OnPlayerOperation", obj.toString());
                Log.i(TAG, "OnPlayerOperation " + operation + " -> " + res);
            } catch (Exception e) {
                Log.e(TAG, "onPlayerOperation error: " + e.getMessage(), e);
            }
        });
    }

    /** Evento del reproductor: "onPrepared", "onSeekComplete", "onCompletion", "onError". */
    public void onPlayerEvent(int instanceId, String event, int err, int extra, long data) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("event", event);
                obj.put("err", err);
                obj.put("extra", extra);
                obj.put("data", data);
                obj.put("reason", "");
                String res = callDirect("OnPlayerEvent", obj.toString());
                Log.i(TAG, "OnPlayerEvent " + event + " -> " + res);
            } catch (Exception e) {
                Log.e(TAG, "onPlayerEvent error: " + e.getMessage(), e);
            }
        });
    }

    /** Por dónde va (ms) y cuánto tiene cargado por delante (ms). */
    public void onPlayBuffer(int instanceId, long progressMs, long bufferMs) {
        handler.post(() -> {
            try {
                JSONObject obj = new JSONObject();
                obj.put("instance", instanceId);
                obj.put("progress", progressMs);
                obj.put("buffer", bufferMs);
                callDirect("OnPlayBuffer", obj.toString());
            } catch (Exception e) {
                Log.e(TAG, "onPlayBuffer error: " + e.getMessage(), e);
            }
        });
    }
}
