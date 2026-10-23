package com.titan.ranger;

import android.text.TextUtils;
import android.util.Log;
import com.google.gson.Gson;
import com.titan.ranger.bean.RangerResult;
import org.json.JSONException;
import org.json.JSONObject;

public class JniHandler {
    private static final String TAG = "JniHandler";
    private static a[] f11429a = new a[10];
    private static final Gson gson = new Gson();

    static {
        Log.i(TAG, "JniHandler class loaded");
    }

    public JniHandler() {
        Log.i(TAG, "JniHandler instance created (JNI_OnLoad)");
    }

    public interface a {
        int a(int i10, String str, String str2, String str3);
        int b();
        int c(String str, String str2, int i10);
        int d(int i10, String str, Object obj, long j10);
        int t(String str, String str2, long j10);
    }

    public static void d(int i10, a aVar) {
        if (i10 >= 0 && i10 < f11429a.length) {
            f11429a[i10] = aVar;
        }
    }

    // Called directly by libranger-jni.so
    private String Callback(String str, String str2) {
        Log.d(TAG, "Native Callback event=" + str + " data=" + str2);
        RangerResult rangerResult = new RangerResult(0, "");
        if (str == null) return gson.toJson(rangerResult);

        switch (str) {
            case "OnPrepareEvent":
                if (!TextUtils.isEmpty(str2)) {
                    try {
                        JSONObject jSONObject = new JSONObject(str2);
                        int instance = jSONObject.optInt("instance", 0);
                        String event = jSONObject.optString("event", "");
                        String statusStr = jSONObject.optString("status", "");
                        Status status = gson.fromJson(statusStr, Status.class);
                        long err = jSONObject.optLong("err", 0);
                        rangerResult = b(instance, event, status, err);
                    } catch (JSONException e10) {
                        Log.e(TAG, "OnPrepareEvent json parse err: " + e10.getMessage());
                        rangerResult.setErr(22);
                    }
                } else {
                    rangerResult.setErr(22);
                }
                break;
            case "SetPlayerUI":
                if (!TextUtils.isEmpty(str2)) {
                    try {
                        JSONObject jSONObject2 = new JSONObject(str2);
                        rangerResult = e(jSONObject2.optInt("instance", 0), jSONObject2.optString("object", ""), jSONObject2.optString("action", ""), jSONObject2.optInt("data", 0));
                    } catch (JSONException e11) {
                        rangerResult.setErr(22);
                    }
                }
                break;
            case "OnReport":
                if (!TextUtils.isEmpty(str2)) {
                    try {
                        JSONObject jSONObject3 = new JSONObject(str2);
                        rangerResult = c(jSONObject3.optInt("instance", 0), jSONObject3.optString("event", ""), jSONObject3.optString("data", ""), jSONObject3.optString("extra", ""));
                    } catch (Exception e12) {
                        rangerResult.setErr(22);
                    }
                }
                break;
            case "OnPrefetchAd":
                if (!TextUtils.isEmpty(str2)) {
                    try {
                        JSONObject jSONObject4 = new JSONObject(str2);
                        rangerResult = a(jSONObject4.optString("name", ""), jSONObject4.optString("path", ""), jSONObject4.optInt("err", 0));
                    } catch (Exception e13) {
                        rangerResult.setErr(22);
                    }
                }
                break;
            default:
                rangerResult.setErr(2);
                break;
        }
        return gson.toJson(rangerResult);
    }

    private RangerResult a(String str, String str2, long j10) {
        RangerResult rangerResult = new RangerResult(0, "");
        if (TextUtils.isEmpty(str) || TextUtils.isEmpty(str2)) {
            rangerResult.setErr(22);
        } else {
            a aVar = f11429a[0];
            if (aVar != null) {
                rangerResult.setErr(aVar.t(str, str2, j10));
            }
        }
        return rangerResult;
    }

    private RangerResult b(int i10, String str, Object obj, long j10) {
        RangerResult rangerResult = new RangerResult(0, "");
        if (obj instanceof Status) {
            a aVar = (i10 >= 0 && i10 < f11429a.length) ? f11429a[i10] : null;
            if (aVar != null) {
                rangerResult.setErr(aVar.d(i10, str, (Status) obj, j10));
            }
        } else {
            rangerResult.setErr(22);
        }
        return rangerResult;
    }

    private RangerResult c(int i10, String str, String str2, String str3) {
        RangerResult rangerResult = new RangerResult(0, "");
        if (TextUtils.isEmpty(str2) || TextUtils.isEmpty(str)) {
            rangerResult.setErr(22);
        } else {
            a aVar = (i10 >= 0 && i10 < f11429a.length) ? f11429a[i10] : null;
            if (aVar != null) {
                rangerResult.setErr(aVar.a(i10, str, str2, str3));
            }
        }
        return rangerResult;
    }

    private RangerResult e(int i10, String str, String str2, int i11) {
        RangerResult rangerResult = new RangerResult(0, "");
        if (TextUtils.isEmpty(str) || TextUtils.isEmpty(str2)) {
            rangerResult.setErr(22);
        } else {
            a aVar = (i10 >= 0 && i10 < f11429a.length) ? f11429a[i10] : null;
            if (aVar != null) {
                rangerResult.setErr(aVar.c(str, str2, i11));
            }
        }
        return rangerResult;
    }
}
