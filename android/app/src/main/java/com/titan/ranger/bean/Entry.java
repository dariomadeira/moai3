package com.titan.ranger.bean;

import java.util.List;

public class Entry {
    private List<String> auths;
    private String buss;
    private int enable;
    private String gslb_params;
    private String main_addr;
    private String main_addr_code;
    private String name;
    private int priority;
    private String redirect;
    private String sign_type;
    private String spare_addr;
    private String spare_addr_code;
    private String strategy;
    private String tag;

    public Entry() {
    }

    public Entry(String name, String buss, String strategy, String main_addr, String main_addr_code,
                 String spare_addr, String spare_addr_code, String redirect, String tag, String sign_type,
                 int priority, int enable, List<String> auths, String gslb_params) {
        this.name = name;
        this.buss = buss;
        this.strategy = strategy;
        this.main_addr = main_addr;
        this.main_addr_code = main_addr_code;
        this.spare_addr = spare_addr;
        this.spare_addr_code = spare_addr_code;
        this.redirect = redirect;
        this.tag = tag;
        this.sign_type = sign_type;
        this.priority = priority;
        this.enable = enable;
        this.auths = auths;
        this.gslb_params = gslb_params;
    }

    public List<String> getAuths() { return auths; }
    public void setAuths(List<String> auths) { this.auths = auths; }

    public String getBuss() { return buss; }
    public void setBuss(String buss) { this.buss = buss; }

    public int getEnable() { return enable; }
    public void setEnable(int enable) { this.enable = enable; }

    public String getGslb_params() { return gslb_params; }
    public void setGslb_params(String gslb_params) { this.gslb_params = gslb_params; }

    public String getMain_addr() { return main_addr; }
    public void setMain_addr(String main_addr) { this.main_addr = main_addr; }

    public String getMain_addr_code() { return main_addr_code; }
    public void setMain_addr_code(String main_addr_code) { this.main_addr_code = main_addr_code; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public int getPriority() { return priority; }
    public void setPriority(int priority) { this.priority = priority; }

    public String getRedirect() { return redirect; }
    public void setRedirect(String redirect) { this.redirect = redirect; }

    public String getSign_type() { return sign_type; }
    public void setSign_type(String sign_type) { this.sign_type = sign_type; }

    public String getSpare_addr() { return spare_addr; }
    public void setSpare_addr(String spare_addr) { this.spare_addr = spare_addr; }

    public String getSpare_addr_code() { return spare_addr_code; }
    public void setSpare_addr_code(String spare_addr_code) { this.spare_addr_code = spare_addr_code; }

    public String getStrategy() { return strategy; }
    public void setStrategy(String strategy) { this.strategy = strategy; }

    public String getTag() { return tag; }
    public void setTag(String tag) { this.tag = tag; }
}
