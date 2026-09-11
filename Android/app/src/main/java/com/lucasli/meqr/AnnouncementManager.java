package com.lucasli.meqr;

import android.app.*; import android.content.*; import android.graphics.Color; import android.webkit.WebView; import android.widget.*; import org.json.*; import java.io.*; import java.net.*;

final class AnnouncementManager {
  private static final String URL="https://meqrcode.cn/announcements/feed.json", KEY="read_announcement";
  private final MainActivity activity; private JSONObject latest;
  AnnouncementManager(MainActivity a){activity=a;}
  void refresh(){new Thread(()->{try{HttpURLConnection c=(HttpURLConnection)new URL(URL).openConnection(); c.setConnectTimeout(8000); c.setReadTimeout(10000); JSONObject f=new JSONObject(read(c.getInputStream())); JSONObject n=f.getJSONObject("latest"); if(!n.optString("id").equals(activity.getPreferences(0).getString(KEY,""))){latest=n; activity.runOnUiThread(()->activity.renderAnnouncement(this));}}catch(Exception ignored){}}).start();}
  void open(){if(latest==null)return; WebView w=new WebView(activity); w.getSettings().setJavaScriptEnabled(false); w.loadUrl(latest.optString("url")); new AlertDialog.Builder(activity).setTitle(latest.optString("title")).setView(w).setPositiveButton("关闭",(d,x)->{activity.getPreferences(0).edit().putString(KEY,latest.optString("id")).apply(); latest=null; activity.renderMain();}).show();}
  String summary(){return latest==null?"":latest.optString("summary");}
  private static String read(InputStream in)throws Exception{try(BufferedReader r=new BufferedReader(new InputStreamReader(in,"UTF-8"))){StringBuilder s=new StringBuilder();String l;while((l=r.readLine())!=null)s.append(l);return s.toString();}}
}
