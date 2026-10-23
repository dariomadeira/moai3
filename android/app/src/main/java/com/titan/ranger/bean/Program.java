package com.titan.ranger.bean;

import java.util.List;

public class Program {
    private String buss;
    private String cause;
    private String episode;
    private String from;
    private String media;
    private List<Media> medias;
    private String name;
    private long start;
    private String title;

    public Program() {
    }

    public Program(String name, String buss, String title, String episode, String from, String cause, List<Media> medias, String media, long start) {
        this.name = name;
        this.buss = buss;
        this.title = title;
        this.episode = episode;
        this.from = from;
        this.cause = cause;
        this.medias = medias;
        this.media = media;
        this.start = start;
    }

    public String getBuss() { return buss; }
    public void setBuss(String buss) { this.buss = buss; }

    public String getCause() { return cause; }
    public void setCause(String cause) { this.cause = cause; }

    public String getEpisode() { return episode; }
    public void setEpisode(String episode) { this.episode = episode; }

    public String getFrom() { return from; }
    public void setFrom(String from) { this.from = from; }

    public String getMedia() { return media; }
    public void setMedia(String media) { this.media = media; }

    public List<Media> getMedias() { return medias; }
    public void setMedias(List<Media> medias) { this.medias = medias; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public long getStart() { return start; }
    public void setStart(long start) { this.start = start; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
}
