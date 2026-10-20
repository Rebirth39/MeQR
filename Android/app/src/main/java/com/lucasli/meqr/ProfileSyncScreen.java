package com.lucasli.meqr;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Manual sync keeps cloud writes outside the card editor. */
final class ProfileSyncScreen {
    private final Activity activity;
    private final List<MeQrProfile> profiles;
    private final ProfileStore store;
    private final Runnable refreshed;
    private final ProfileSyncClient client;
    private final I18n i18n;
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private Dialog dialog;
    private Context ui;
    private LinearLayout content;
    private MeQrProfile selected;
    private JSONObject binding,devices;
    private String invite="",message="";
    private boolean busy;
    private EditText code;
    interface Work {void run() throws Exception;}
    ProfileSyncScreen(Activity a,List<MeQrProfile> p,ProfileStore s,Runnable refreshed) {activity=a;profiles=p;store=s;this.refreshed=refreshed;client=new ProfileSyncClient(a);i18n=new I18n(a);selected=p.isEmpty()?null:p.get(0);}
    void show() {
        dialog=new Dialog(activity);ui=dialog.getContext();dialog.setOnDismissListener(d->{worker.shutdown();refreshed.run();});render();dialog.show();
        android.view.Window window=dialog.getWindow();
        if(window!=null){
            window.setBackgroundDrawable(new ColorDrawable(Ui.BG));
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT,ViewGroup.LayoutParams.MATCH_PARENT);
            window.getDecorView().setSystemUiVisibility(0);
            window.setStatusBarColor(Ui.BG);window.setNavigationBarColor(Ui.BG);
            if(Build.VERSION.SDK_INT>=30)window.setDecorFitsSystemWindows(false);
        }
        if (!activity.getSharedPreferences("settings", Context.MODE_PRIVATE).getBoolean("sync_privacy_ack_v1", false)) {
            new AlertDialog.Builder(Ui.dialogContext(activity)).setTitle(i18n.t("syncPrivacyTitle"))
                    .setMessage(i18n.t("syncPrivacyBody"))
                    .setNeutralButton(i18n.t("viewFullPolicy"), (d,w)->{dialog.dismiss();activity.startActivity(new android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("https://meqrcode.cn/legal")));})
                    .setNegativeButton(i18n.t("cancel"), (d,w)->dialog.dismiss())
                    .setOnCancelListener(d->dialog.dismiss())
                    .setPositiveButton(i18n.t("syncPrivacyAgree"), (d,w)->activity.getSharedPreferences("settings", Context.MODE_PRIVATE).edit().putBoolean("sync_privacy_ack_v1",true).apply())
                    .show();
        }
    }
    private int dp(int value) {return Ui.dp(activity,value);}
    private LinearLayout.LayoutParams fillWidth() {return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,ViewGroup.LayoutParams.WRAP_CONTENT);}
    private TextView title(String value) {TextView t=Ui.boldText(ui,value,Ui.TEXT,24);t.setPadding(0,dp(6),0,dp(10));return t;}
    private TextView body(String value) {TextView t=Ui.text(ui,value,Ui.MUTED,14);t.setLineSpacing(dp(3),1.1f);t.setPadding(0,dp(3),0,dp(3));return t;}
    private TextView section(String value) {TextView t=Ui.boldText(ui,value,Ui.TEAL,13);t.setLetterSpacing(0.08f);t.setPadding(0,0,0,dp(8));return t;}
    private LinearLayout card(String sectionTitle) {
        LinearLayout card=new LinearLayout(ui);card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(Ui.rounded(Ui.SURFACE,dp(18),Ui.BORDER,dp(1)));
        card.setPadding(dp(16),dp(14),dp(16),dp(8));
        LinearLayout.LayoutParams lp=fillWidth();lp.setMargins(0,0,0,dp(14));card.setLayoutParams(lp);
        content.addView(card);
        if(sectionTitle!=null)card.addView(section(sectionTitle));
        return card;
    }
    private void normalizeButton(Button button) {
        button.setAllCaps(false);button.setMinWidth(0);button.setMinHeight(0);button.setMinimumWidth(0);button.setMinimumHeight(0);
        button.setIncludeFontPadding(false);button.setPadding(dp(10),0,dp(10),0);
        if(Build.VERSION.SDK_INT>=21)button.setStateListAnimator(null);
    }
    private void styleButton(Button b,LinearLayout parent,int topMargin) {
        normalizeButton(b);b.setGravity(Gravity.CENTER);b.setTextSize(15);b.setMinHeight(dp(46));
        b.setEnabled(!busy);b.setAlpha(busy?0.45f:1f);
        LinearLayout.LayoutParams lp=fillWidth();lp.setMargins(0,dp(topMargin),0,dp(8));parent.addView(b,lp);
    }
    private void primary(LinearLayout parent,String label,Runnable action) {
        Button b=Ui.button(ui,label);b.setTextColor(Color.WHITE);b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setBackground(Ui.tealButton(dp(12)));styleButton(b,parent,10);b.setOnClickListener(v->action.run());
    }
    private void ghost(LinearLayout parent,String label,Runnable action) {
        Button b=Ui.button(ui,label);b.setTextColor(Ui.TEXT);
        b.setBackground(Ui.rounded(Ui.SURFACE_2,dp(12),Ui.BORDER,dp(1)));styleButton(b,parent,10);b.setOnClickListener(v->action.run());
    }
    private void danger(LinearLayout parent,String label,Runnable action) {
        Button b=Ui.button(ui,label);b.setTextColor(Color.rgb(235,110,110));
        b.setBackground(Ui.rounded(Ui.SURFACE_2,dp(12),Color.rgb(96,52,56),dp(1)));styleButton(b,parent,10);b.setOnClickListener(v->action.run());
    }
    private void render() {
        if(activity.isFinishing())return;
        ScrollView scroll=new ScrollView(ui);scroll.setBackground(Ui.gradient(Ui.BG_TOP,Ui.BG,0));
        content=new LinearLayout(ui);content.setOrientation(LinearLayout.VERTICAL);
        int pad=dp(20);content.setPadding(pad,dp(16),pad,pad);scroll.addView(content);dialog.setContentView(scroll);
        scroll.setOnApplyWindowInsetsListener((v,insets)->{
            v.setPadding(0,insets.getSystemWindowInsetTop(),0,insets.getSystemWindowInsetBottom());return insets;
        });scroll.requestApplyInsets();
        content.addView(title(i18n.t("syncTitle")));
        content.addView(body(i18n.t("syncIntro1")));
        content.addView(body(i18n.t("syncIntro2")));
        content.addView(body(i18n.t("syncIntro3")));
        if(busy){ProgressBar p=new ProgressBar(ui);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT,ViewGroup.LayoutParams.WRAP_CONTENT);lp.gravity=Gravity.CENTER_HORIZONTAL;lp.setMargins(0,dp(24),0,0);content.addView(p,lp);TextView t=body(i18n.t("syncSyncing"));t.setGravity(Gravity.CENTER);t.setTextColor(Ui.TEXT);t.setTextSize(16);content.addView(t);return;}
        LinearLayout mine=card(i18n.t("syncLocalCards"));
        if(!profiles.isEmpty()) {
            List<String> names=new ArrayList<>();for(MeQrProfile p:profiles)names.add(p.name);
            ArrayAdapter<String> adapter=new ArrayAdapter<String>(ui,android.R.layout.simple_spinner_item,names) {
                @Override public View getView(int position,View convertView,ViewGroup parent) {TextView t=(TextView)super.getView(position,convertView,parent);t.setTextColor(Ui.TEXT);t.setTextSize(16);return t;}
                @Override public View getDropDownView(int position,View convertView,ViewGroup parent) {TextView t=(TextView)super.getDropDownView(position,convertView,parent);t.setTextColor(Ui.TEXT);t.setTextSize(16);t.setPadding(dp(16),dp(12),dp(16),dp(12));return t;}
            };
            Spinner picker=new Spinner(ui);picker.setAdapter(adapter);
            picker.setBackground(Ui.rounded(Ui.SURFACE_2,dp(12),Ui.BORDER,dp(1)));picker.setPadding(dp(12),0,dp(8),0);
            picker.setPopupBackgroundDrawable(Ui.rounded(Ui.SURFACE_2,dp(12)));
            mine.addView(picker,fillWidth());
            int index=profiles.indexOf(selected);picker.setSelection(Math.max(0,index));
            picker.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener(){public void onNothingSelected(android.widget.AdapterView<?> p){}public void onItemSelected(android.widget.AdapterView<?> p,View v,int position,long id){if(selected!=profiles.get(position)){selected=profiles.get(position);devices=null;invite="";render();}}});
        }
        try {binding=selected==null?null:client.secret(selected.id);}catch(Exception e){message=e.getLocalizedMessage();binding=null;}
        if(selected!=null) {
            if(binding==null)primary(mine,i18n.t("syncEnable"),()->run(()->{client.create(selected);commit(client.sync(selected,null));message=i18n.t("syncEnabled");}));
            else {
                TextView status=Ui.boldText(ui,(binding.optString("role").equals("owner")?i18n.t("syncRoleOwner"):i18n.t("syncRoleBound"))+" · "+i18n.t("syncCloudVersion")+" "+binding.optInt("revision"),Ui.TEAL,14);status.setPadding(0,dp(10),0,0);mine.addView(status);
                primary(mine,i18n.t("syncNow"),()->sync(null));ghost(mine,i18n.t("syncRefreshDevices"),()->run(this::loadDevices));
                if(binding.optString("role").equals("owner")) {
                    ghost(mine,i18n.t("syncGenerateCode"),()->run(()->{invite=client.api(ProfileSyncClient.path(binding)+"/invite","POST",binding.getString("token"),new JSONObject()).getString("code");loadDevices();}));
                    if(!invite.isEmpty()){
                        TextView shown=Ui.boldText(ui,formatCode(invite),Ui.TEAL,22);shown.setGravity(Gravity.CENTER);shown.setLetterSpacing(0.12f);shown.setTypeface(Typeface.MONOSPACE,Typeface.BOLD);
                        shown.setBackground(Ui.rounded(Ui.SURFACE_2,dp(12),Ui.BORDER,dp(1)));shown.setPadding(dp(12),dp(14),dp(12),dp(14));
                        LinearLayout.LayoutParams lp=fillWidth();lp.setMargins(0,dp(10),0,0);mine.addView(shown,lp);
                        primary(mine,i18n.t("syncCopyCode"),()->{((ClipboardManager)activity.getSystemService(Context.CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText(i18n.t("meqrBindingCode"),formatCode(invite)));message=i18n.t("syncCopied");render();});
                    }
                }
            }
        }
        if(selected!=null&&binding!=null) {
            LinearLayout zone=card(i18n.t("syncStopSection"));
            danger(zone,binding.optString("role").equals("owner")?i18n.t("syncStopOwner"):i18n.t("syncUnbind"),()->new AlertDialog.Builder(Ui.dialogContext(ui)).setTitle(i18n.t("syncDisconnectTitle"))
                .setMessage(i18n.t("syncDisconnectMessage"))
                .setNegativeButton(i18n.t("cancel"),null).setPositiveButton(i18n.t("continue"),(d,w)->run(()->{
                    String path=ProfileSyncClient.path(binding)+(binding.getString("role").equals("owner")?"":"/devices/"+binding.getString("deviceId"));
                    client.api(path,"DELETE",binding.getString("token"),null);client.saveSecret(selected.id,null);devices=null;invite="";message=i18n.t("syncStopped");
                })).show());
            ghost(zone,i18n.t("syncClearCredential"),()->new AlertDialog.Builder(Ui.dialogContext(ui)).setTitle(i18n.t("syncClearTitle")).setMessage(i18n.t("syncClearMessage"))
                .setNegativeButton(i18n.t("cancel"),null).setPositiveButton(i18n.t("syncClearAction"),(d,w)->run(()->{client.saveSecret(selected.id,null);devices=null;invite="";message=i18n.t("syncStoppedLocal");})).show());
        }
        if(binding!=null&&devices!=null) {
            LinearLayout deviceCard=card(i18n.t("syncBoundDevices"));JSONArray list=devices.optJSONArray("devices");
            if(list!=null)for(int i=0;i<list.length();i++){JSONObject device=list.optJSONObject(i);if(device==null)continue;
                LinearLayout row=new LinearLayout(ui);row.setOrientation(LinearLayout.HORIZONTAL);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(0,dp(6),0,dp(6));
                TextView name=Ui.text(ui,device.optString("name")+(device.optString("id").equals(binding.optString("deviceId"))?i18n.t("syncThisDevice"):""),Ui.TEXT,16);
                row.addView(name,new LinearLayout.LayoutParams(0,ViewGroup.LayoutParams.WRAP_CONTENT,1));deviceCard.addView(row);
                if(binding.optString("role").equals("owner")&&!device.optString("role").equals("owner")){
                    Button remove=Ui.button(ui,i18n.t("syncRemove"));remove.setTextColor(Color.rgb(235,110,110));remove.setTextSize(13);
                    remove.setBackground(Ui.rounded(Ui.SURFACE_2,dp(10),Color.rgb(96,52,56),dp(1)));normalizeButton(remove);remove.setPadding(dp(14),dp(6),dp(14),dp(6));
                    remove.setEnabled(!busy);remove.setOnClickListener(v->run(()->{client.api(ProfileSyncClient.path(binding)+"/devices/"+device.getString("id"),"DELETE",binding.getString("token"),null);loadDevices();}));
                    row.addView(remove);
                }
            }
            JSONArray waiting=devices.optJSONArray("pending");if(binding.optString("role").equals("owner")&&waiting!=null&&waiting.length()>0){TextView pendingNote=section(i18n.t("syncPendingDevices"));pendingNote.setPadding(0,dp(12),0,0);deviceCard.addView(pendingNote);for(int i=0;i<waiting.length();i++){JSONObject d=waiting.optJSONObject(i);if(d!=null)primary(deviceCard,i18n.tf("syncAllowName",d.optString("name")),()->run(()->{client.api(ProfileSyncClient.path(binding)+"/approve/"+d.getString("id"),"POST",binding.getString("token"),new JSONObject());loadDevices();message=i18n.t("syncAllowed");}));}}
        }
        LinearLayout joinCard=card(i18n.t("syncJoinSection"));JSONObject pending=null;try{pending=client.secret("pendingJoin");}catch(Exception e){message=e.getLocalizedMessage();}
        code=new EditText(ui);code.setTextColor(Ui.TEXT);code.setHintTextColor(Ui.DIM);code.setSingleLine(true);code.setHint("____-____-____-____");
        code.setTextSize(20);code.setTypeface(Typeface.MONOSPACE,Typeface.BOLD);code.setLetterSpacing(0.12f);code.setGravity(Gravity.CENTER);
        code.setBackground(Ui.rounded(Ui.SURFACE_2,dp(12),Ui.BORDER,dp(1)));code.setPadding(dp(12),dp(14),dp(12),dp(14));
        code.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        joinCard.addView(code,fillWidth());
        code.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence x,int a,int b,int c){} public void onTextChanged(CharSequence x,int a,int b,int c){} public void afterTextChanged(android.text.Editable e){String f=formatCode(e.toString()); if(!f.equals(e.toString())){code.removeTextChangedListener(this); code.setText(f); code.setSelection(f.length()); code.addTextChangedListener(this);}}});
        if(pending!=null){code.setText(pending.optString("code"));code.setEnabled(false);}
        primary(joinCard,pending==null?i18n.t("syncApplyJoin"):i18n.t("syncCheckJoin"),()->{String value=normalizeCode(code.getText().toString());run(()->join(value));});
        if(pending!=null)ghost(joinCard,i18n.t("syncCancelJoin"),()->run(()->{client.saveSecret("pendingJoin",null);message=i18n.t("syncJoinCancelled");}));
        TextView note=body(i18n.t("syncJoinHint"));note.setPadding(0,dp(4),0,dp(8));joinCard.addView(note);
        if(!message.isEmpty()){TextView t=Ui.boldText(ui,message,Ui.TEXT,15);t.setPadding(0,dp(2),0,dp(14));content.addView(t);}
        ghost(content,i18n.t("done"),()->dialog.dismiss());
    }
    private void run(Work work) {
        if (!activity.getSharedPreferences("settings", Context.MODE_PRIVATE).getBoolean("sync_privacy_ack_v1", false)) return;
        if(busy)return;busy=true;message="";dialog.setCancelable(false);render();
        worker.execute(()->{
            Exception failure=null;try{work.run();}catch(Exception e){failure=e;}catch(OutOfMemoryError e){failure=new java.io.IOException(i18n.t("syncErrImageMemory"));}
            final Exception error=failure;
            activity.runOnUiThread(()->{if(activity.isFinishing()||activity.isDestroyed()||dialog==null||!dialog.isShowing())return;busy=false;dialog.setCancelable(true);if(error!=null)message=error.getLocalizedMessage();render();});
        });
    }
    private void loadDevices() throws Exception {devices=client.api(ProfileSyncClient.path(binding)+"/devices","GET",binding.getString("token"),null);}
    private void sync(String resolution) {run(()->{
        try{commit(client.sync(selected,resolution));message=i18n.t("syncDone");}
        catch(ProfileSyncClient.Failure e){if(e.status!=409)throw e;message=e.getMessage();activity.runOnUiThread(()->new AlertDialog.Builder(Ui.dialogContext(ui)).setTitle(i18n.t("syncConflictTitle"))
            .setMessage(i18n.t("syncConflictMessage"))
            .setNegativeButton(i18n.t("syncConflictLater"),null).setNeutralButton(i18n.t("syncConflictRemote"),(d,w)->sync("remote")).setPositiveButton(i18n.t("syncConflictLocal"),(d,w)->sync("local")).show());}
    });}
    private void commit(ProfileSyncClient.Result result) throws Exception {
        List<MeQrProfile> updated=new ArrayList<>(profiles);int index=-1;for(int i=0;i<updated.size();i++)if(updated.get(i).id.equals(result.profile.id))index=i;
        if(index<0)updated.add(result.profile);else updated.set(index,result.profile);
        store.save(updated);
        java.util.concurrent.CountDownLatch applied=new java.util.concurrent.CountDownLatch(1);
        activity.runOnUiThread(()->{try{profiles.clear();profiles.addAll(updated);selected=result.profile;}finally{applied.countDown();}});
        applied.await();
        client.saveSecret(selected.id,result.binding);
    }
    static String normalizeCode(String value){ String clean=value.replace("-","").replaceAll("\\s",""); return clean.length()==32?clean.toLowerCase(Locale.ROOT):clean.toUpperCase(Locale.ROOT); }
    private static String formatCode(String value){ String c=normalizeCode(value); StringBuilder b=new StringBuilder(); for(int i=0;i<c.length();i++){if(i>0&&i%4==0)b.append("-"); b.append(c.charAt(i));} return b.toString(); }
    private void join(String code) throws Exception {
        JSONObject pending=client.secret("pendingJoin");
        if(pending==null){if(!code.matches("(?:[0-9A-Z]{16}|[a-f0-9]{32})"))throw new java.io.IOException(i18n.t("syncErrInvalidCode"));pending=ProfileSyncClient.json("code",code,"token",ProfileSyncClient.token(),"localID",UUID.randomUUID().toString());client.saveSecret("pendingJoin",pending);}
        String token=pending.getString("token");code=pending.getString("code");
        client.api("join","POST",token,ProfileSyncClient.json("code",code,"deviceName",ProfileSyncClient.deviceName()));
        JSONObject snapshot=client.api("claim","POST",token,ProfileSyncClient.json("code",code));
        if(!snapshot.optString("status").equals("approved")){message=i18n.t("syncWaitingOwner");return;}
        String id=pending.getString("localID");MeQrProfile original=new MeQrProfile();original.id=id;original.sortOrder=profiles.size();for(MeQrProfile p:profiles)if(p.id.equals(id))original=p;
        MeQrProfile imported=client.apply(snapshot,original,token);JSONObject b=ProfileSyncClient.binding(snapshot,token);b.put("baseline",ProfileSyncClient.document(imported,client.images(imported)));
        commit(new ProfileSyncClient.Result(imported,b));client.saveSecret("pendingJoin",null);message=i18n.t("syncJoined");
    }
}
