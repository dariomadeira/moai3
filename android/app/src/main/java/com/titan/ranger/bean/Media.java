package com.titan.ranger.bean;

public class Media {
    private String format;
    private String lang;
    private String license;
    private String name;
    private String quality;
    private String vcodec;

    public Media() {
    }

    public Media(String name, String license, String lang, String quality, String vcodec, String format) {
        this.name = name;
        this.license = license;
        this.lang = lang;
        this.quality = quality;
        this.vcodec = vcodec;
        this.format = format;
    }

    public String getFormat() { return format; }
    public void setFormat(String format) { this.format = format; }

    public String getLang() { return lang; }
    public void setLang(String lang) { this.lang = lang; }

    public String getLicense() { return license; }
    public void setLicense(String license) { this.license = license; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getQuality() { return quality; }
    public void setQuality(String quality) { this.quality = quality; }

    public String getVcodec() { return vcodec; }
    public void setVcodec(String vcodec) { this.vcodec = vcodec; }
}
