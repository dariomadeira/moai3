package com.titan.ranger;

import java.util.List;

public class Status {
    long buffer;
    String buss;
    String format;
    String host;
    long latency;
    List<String> links;
    String media;
    long media_buffer;
    String play_url;
    String program;
    String snapinfo_url;
    String snapshot_url;
    String title;
    boolean url_modified;

    public long getBuffer() { return buffer; }
    public void setBuffer(long buffer) { this.buffer = buffer; }

    public String getBuss() { return buss; }
    public void setBuss(String buss) { this.buss = buss; }

    public String getFormat() { return format; }
    public void setFormat(String format) { this.format = format; }

    public String getHost() { return host; }
    public void setHost(String host) { this.host = host; }

    public long getLatency() { return latency; }
    public void setLatency(long latency) { this.latency = latency; }

    public List<String> getLinks() { return links; }
    public void setLinks(List<String> links) { this.links = links; }

    public String getMedia() { return media; }
    public void setMedia(String media) { this.media = media; }

    public long getMedia_buffer() { return media_buffer; }
    public void setMedia_buffer(long media_buffer) { this.media_buffer = media_buffer; }

    public String getPlay_url() { return play_url; }
    public void setPlay_url(String play_url) { this.play_url = play_url; }

    public String getProgram() { return program; }
    public void setProgram(String program) { this.program = program; }

    public String getSnapinfo_url() { return snapinfo_url; }
    public void setSnapinfo_url(String snapinfo_url) { this.snapinfo_url = snapinfo_url; }

    public String getSnapshot_url() { return snapshot_url; }
    public void setSnapshot_url(String snapshot_url) { this.snapshot_url = snapshot_url; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public boolean isUrl_modified() { return url_modified; }
    public void setUrl_modified(boolean url_modified) { this.url_modified = url_modified; }

    @Override
    public String toString() {
        return "Status{program='" + program + "', play_url='" + play_url + "', format='" + format + "', media_buffer=" + media_buffer + "}";
    }
}
