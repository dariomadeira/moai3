package com.titan.ranger.bean;

public class RangerResult {
    private int err;
    private String res;

    public RangerResult(int err, String res) {
        this.err = err;
        this.res = res != null ? res : "";
    }

    public int getErr() {
        return err;
    }

    public void setErr(int err) {
        this.err = err;
    }

    public String getRes() {
        return res;
    }

    public void setRes(String res) {
        this.res = res;
    }

    @Override
    public String toString() {
        return "RangerResult(err=" + err + ", res=" + res + ")";
    }
}
