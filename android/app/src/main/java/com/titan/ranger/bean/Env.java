package com.titan.ranger.bean;

public class Env {
    private String android_id;
    private String app;
    private String app_ver;
    private String communication_key;
    private String dev_id;
    private String params;
    private int titan_port;
    private String user_id;

    public Env() {
    }

    public Env(String app, String app_ver, String user_id, String dev_id, String communication_key, String params, String android_id, int titan_port) {
        this.app = app;
        this.app_ver = app_ver;
        this.user_id = user_id;
        this.dev_id = dev_id;
        this.communication_key = communication_key;
        this.params = params;
        this.android_id = android_id;
        this.titan_port = titan_port;
    }

    public String getAndroid_id() { return android_id; }
    public void setAndroid_id(String android_id) { this.android_id = android_id; }

    public String getApp() { return app; }
    public void setApp(String app) { this.app = app; }

    public String getApp_ver() { return app_ver; }
    public void setApp_ver(String app_ver) { this.app_ver = app_ver; }

    public String getCommunication_key() { return communication_key; }
    public void setCommunication_key(String communication_key) { this.communication_key = communication_key; }

    public String getDev_id() { return dev_id; }
    public void setDev_id(String dev_id) { this.dev_id = dev_id; }

    public String getParams() { return params; }
    public void setParams(String params) { this.params = params; }

    public int getTitan_port() { return titan_port; }
    public void setTitan_port(int titan_port) { this.titan_port = titan_port; }

    public String getUser_id() { return user_id; }
    public void setUser_id(String user_id) { this.user_id = user_id; }
}
