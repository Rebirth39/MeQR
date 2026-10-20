package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.*;
import java.io.FileOutputStream;
import java.lang.reflect.*;
import java.util.*;

/** Runs only against an isolated applicationId; never reads a user's installed card store. */
public final class PlatformPickerInstrumentation extends Instrumentation {
    private MainActivity activity;
    private I18n lang;
    private boolean baseline;
    private final StringBuilder log = new StringBuilder();
    @Override public void onCreate(Bundle args) { super.onCreate(args); baseline = args.getBoolean("baseline", false) || "true".equals(args.getString("baseline")); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".platformpickertest"), "Isolated package required");
            getTargetContext().getSharedPreferences("settings", 0).edit().clear()
                    .putBoolean("android_profile_v1", true).putString("legal_ack_version", "2026-09-16").commit();
            lang = new I18n(getTargetContext()); lang.setLanguageMode(I18n.ZH_HANS);
            MeQrProfile fixture = new MeQrProfile(); fixture.name = "Platform test";
            MeQrItem qr = new MeQrItem(); qr.platform = "wechat"; qr.qrContent = "https://example.com/platform-test";
            fixture.qrItems.clear(); fixture.qrItems.add(qr);
            new ProfileStore(getTargetContext()).save(new ArrayList<>(Collections.singletonList(fixture)));
            activity = (MainActivity) startActivitySync(new Intent().setClassName(getTargetContext(), MainActivity.class.getName()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            for (boolean dark : new boolean[]{false, true, false}) {
                main(() -> invoke("setDarkTheme", new Class<?>[]{boolean.class}, dark));
                MeQrItem item = new MeQrItem(); item.platform = "wechat";
                Button button = new Button(activity); EditText custom = new EditText(activity);
                open(item, button, custom);
                screenshot((baseline ? "before-" : "after-") + (dark ? "dark" : "light") + ".png");
                main(() -> {
                    ListView list = list(); check(list.isItemChecked(0), "Current WeChat selected");
                    double contrast = contrast(((TextView)list.getChildAt(0)).getCurrentTextColor(), Ui.BG);
                    log.append("theme=").append(dark).append(" text contrast=").append(contrast).append('\n');
                    if (!baseline) check(contrast >= 4.5, "Platform names readable");
                });
                if (baseline) { check(!dark, "baseline only"); break; }
                String[] tabs = {"commonPlatforms", "socialPlatforms", "professionalPlatforms", "custom"};
                for (String tab : tabs) {
                    main(() -> find(lang.t(tab)).performClick()); waitForIdleSync();
                    main(() -> {
                        ListView list = list(); View recycled = null;
                        for (int i=0;i<list.getCount();i++) {
                            recycled = list.getAdapter().getView(i,recycled,list);
                            check(contrast(((TextView)recycled).getCurrentTextColor(),Ui.BG)>=4.5,"Recycled row contrast: "+i);
                        }
                        for (String text : new String[]{lang.t("platform"),lang.t("cancel"),lang.t(tab)})
                            check(contrast(find(text).getCurrentTextColor(),Ui.BG)>=4.5,"Dialog text contrast: "+text);
                    });
                }
                tap(find(lang.t("custom"), CheckedTextView.class));
                main(() -> check(item.platform.equals("custom") && custom.getVisibility()==View.VISIBLE,"Custom selection reveals name"));
                open(item,button,custom);
                main(() -> { check(list().getCount()==1 && list().isItemChecked(0),"Reopen custom group/selection"); find(lang.t("commonPlatforms")).performClick(); });
                waitForIdleSync();
                // Scroll to the last common platform, exercising the list's recycled rows.
                main(() -> list().setSelection(6)); waitForIdleSync();
                tap(find("GitHub",CheckedTextView.class));
                main(() -> check(item.platform.equals("github") && custom.getVisibility()==View.GONE && button.getText().toString().equals("GitHub"),"Selection updates platform and hides custom"));
                open(item,button,custom); main(() -> check(list().isItemChecked(6),"Reopen selected GitHub"));
                tap(find(lang.t("cancel"))); main(() -> check(item.platform.equals("github"),"Cancel preserves value"));
            }
            if (!baseline) {
                // Real editor entry and persisted save, rather than a standalone picker fixture.
                main(() -> invoke("showEditor",new Class<?>[]{MeQrProfile.class},((List<MeQrProfile>)field(activity,"profiles")).get(0)));
                waitForIdleSync(); main(() -> find(lang.t("wechat")).performClick()); waitForIdleSync();
                tap(find("QQ",CheckedTextView.class));
                main(() -> { MeQrProfile editing=(MeQrProfile)field(field(activity,"editSession"),"profile"); check(editing.qrItems.get(0).platform.equals("qq"),"Editor draft selected QQ, got "+editing.qrItems.get(0).platform); find(lang.t("save")).performClick(); });waitForIdleSync();
                check(new ProfileStore(getTargetContext()).load().get(0).qrItems.get(0).platform.equals("qq"),"Editor selection persisted");
                main(() -> invoke("showOnboarding",new Class<?>[]{}));waitForIdleSync();
                main(() -> find(lang.t("setupStart")).performClick());waitForIdleSync();
                main(() -> {
                    ((EditText)field(field(activity,"editSession"),"name")).setText("New card");
                    find(lang.t("continue")).performClick();
                });waitForIdleSync();
                MeQrProfile draft=(MeQrProfile)field(field(activity,"editSession"),"profile");
                main(() -> find(draft.qrItems.get(0).platformDisplayName(lang)).performClick());waitForIdleSync();
                main(() -> find(lang.t("commonPlatforms")).performClick());waitForIdleSync();
                tap(find("QQ",CheckedTextView.class));check(draft.qrItems.get(0).platform.equals("qq"),"Onboarding picker updates draft");
                log.append("PASS: light/dark/light; all category and recycled row contrasts; selected state; actual touch custom/GitHub/QQ; cancel; editor persistence; onboarding\n");
            }
            result.putString("stream",log.toString());finish(Activity.RESULT_OK,result);
        } catch(Throwable error) { result.putString("stream",log+android.util.Log.getStackTraceString(error));finish(Activity.RESULT_CANCELED,result); }
    }
    private void open(MeQrItem item,Button b,EditText c) { main(() -> invoke("showPlatformPicker",new Class<?>[]{MeQrItem.class,Button.class,EditText.class},item,b,c)); waitForIdleSync(); }
    private void main(Runnable r) { Throwable[] failure={null};runOnMainSync(() -> {try{r.run();}catch(Throwable t){failure[0]=t;}});if(failure[0]!=null)throw new AssertionError(failure[0]); }
    private Object invoke(String name,Class<?>[] types,Object... args) { try{Method m=MainActivity.class.getDeclaredMethod(name,types);m.setAccessible(true);return m.invoke(activity,args);}catch(Exception e){throw new AssertionError(e);} }
    private Object field(Object o,String name) { try{Field f=o.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(o);}catch(Exception e){throw new AssertionError(e);} }
    private <T extends View> T node(View root,Class<T> type,String text) {
        if(type.isInstance(root) && (text==null || (root instanceof TextView && text.equals(((TextView)root).getText().toString()))))return type.cast(root);
        if(root instanceof ViewGroup){ViewGroup g=(ViewGroup)root;for(int i=0;i<g.getChildCount();i++){T t=node(g.getChildAt(i),type,text);if(t!=null)return t;}}return null;
    }
    private <T extends View> T top(Class<T> type,String text) { List<View> roots=WindowInspector.getGlobalWindowViews();for(int i=roots.size()-1;i>=0;i--){T v=node(roots.get(i),type,text);if(v!=null)return v;}throw new AssertionError("Missing "+type+" "+text); }
    private ListView list(){return top(ListView.class,null);} private TextView find(String s){return top(TextView.class,s);} private <T extends View>T find(String s,Class<T> c){return top(c,s);}
    private void tap(View v) { SystemClock.sleep(350);waitForIdleSync(); int[] xy=new int[2];main(() -> v.getLocationOnScreen(xy));long t=SystemClock.uptimeMillis();float x=xy[0]+v.getWidth()/2f,y=xy[1]+v.getHeight()/2f;sendPointerSync(MotionEvent.obtain(t,t,0,x,y,0));SystemClock.sleep(60);sendPointerSync(MotionEvent.obtain(t,SystemClock.uptimeMillis(),1,x,y,0));SystemClock.sleep(250);waitForIdleSync(); }
    private void screenshot(String name)throws Exception {SystemClock.sleep(500);waitForIdleSync();Bitmap b=getUiAutomation().takeScreenshot();try(FileOutputStream out=getTargetContext().openFileOutput(name,0)){b.compress(Bitmap.CompressFormat.PNG,100,out);} }
    private static double lum(int c){double[] v={Color.red(c)/255.0,Color.green(c)/255.0,Color.blue(c)/255.0};for(int i=0;i<3;i++)v[i]=v[i]<=.04045?v[i]/12.92:Math.pow((v[i]+.055)/1.055,2.4);return .2126*v[0]+.7152*v[1]+.0722*v[2];}
    private static double contrast(int a,int b){double x=lum(a),y=lum(b);return(Math.max(x,y)+.05)/(Math.min(x,y)+.05);}
    private static void check(boolean v,String m){if(!v)throw new AssertionError(m);}
}
