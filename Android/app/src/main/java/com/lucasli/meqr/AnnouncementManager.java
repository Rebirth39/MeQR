package com.lucasli.meqr;

import android.app.*; import android.content.*; import android.webkit.WebView; import android.webkit.WebSettings; import android.webkit.WebViewClient; import android.graphics.Color; import org.json.*; import java.io.*; import java.net.*;

final class AnnouncementManager {
  private static final String URL="https://meqrcode.cn/announcements/feed.json", KEY="read_announcement";
  private static final long REFRESH_THROTTLE_MS=60_000L;
  private final MainActivity activity; private volatile JSONObject latest; private volatile long lastRefresh;
  AnnouncementManager(MainActivity a){activity=a;}
  void refresh(){refresh(false);}
  void refresh(boolean force){long now=System.currentTimeMillis(); if(!force&&now-lastRefresh<REFRESH_THROTTLE_MS)return; lastRefresh=now; new Thread(()->{try{HttpURLConnection c=(HttpURLConnection)new URL(URL).openConnection(); c.setConnectTimeout(8000); c.setReadTimeout(10000); int status=c.getResponseCode(); if(status<200||status>=300)return; JSONObject f=new JSONObject(read(c.getInputStream())); JSONObject n=f.getJSONObject("latest"); if(!n.optString("id").equals(activity.getPreferences(0).getString(KEY,""))){latest=n; activity.runOnUiThread(()->activity.renderAnnouncement(this));}}catch(Exception ignored){}}).start();}
  private String localized(JSONObject n,String key,String fallback){JSONObject map=n.optJSONObject(key+"ByLanguage"); if(map==null)return n.optString(key,fallback); String lang="zh"; String resolved=new I18n(activity).resolvedLanguage(); if("en".equals(resolved))lang="en"; else if("ja".equals(resolved))lang="ja"; return map.optString(lang, n.optString(key,fallback)); }
  String title(){return latest==null?"":localized(latest,"title","");}
  String summary(){return latest==null?"":localized(latest,"summary","");}
  void open(){final JSONObject current=latest; if(current==null)return; String url=current.optString("url"); if(!isTrusted(url))return; final WebView w=new WebView(activity); w.setBackgroundColor(Color.WHITE); WebSettings settings=w.getSettings(); settings.setJavaScriptEnabled(false); settings.setDomStorageEnabled(true); settings.setDefaultTextEncodingName("UTF-8"); if(android.os.Build.VERSION.SDK_INT>=29) settings.setForceDark(WebSettings.FORCE_DARK_OFF); final String loadedTitle=title(); w.setWebViewClient(new WebViewClient(){@Override public void onPageFinished(WebView view,String u){markRead(current);}}); w.loadUrl(url); AlertDialog dialog=new AlertDialog.Builder(Ui.dialogContext(activity)).setTitle(loadedTitle).setView(w).setPositiveButton(activity.i18nText("done"),(d,x)->{latest=null; activity.renderMain();}).create(); dialog.setOnDismissListener(d->{w.destroy();}); dialog.show();}
  private void markRead(JSONObject n){if(n!=null&&!n.optString("id").isEmpty())activity.getPreferences(0).edit().putString(KEY,n.optString("id")).apply();}
  private static boolean isTrusted(String url){try{java.net.URL u=new java.net.URL(url); return "https".equalsIgnoreCase(u.getProtocol()) && ("meqrcode.cn".equalsIgnoreCase(u.getHost())||u.getHost()!=null&&u.getHost().toLowerCase(java.util.Locale.ROOT).endsWith(".meqrcode.cn"));}catch(Exception e){return false;}}
  private static String read(InputStream in)throws Exception{try(BufferedReader r=new BufferedReader(new InputStreamReader(in,"UTF-8"))){StringBuilder s=new StringBuilder();String l;while((l=r.readLine())!=null)s.append(l);return s.toString();}}
}
