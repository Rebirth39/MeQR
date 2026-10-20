package com.lucasli.meqr;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.*;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Private sync credentials never enter exports, exchange codes, or Android backups. */
final class ProfileSyncClient {
    static final String ENDPOINT = "https://profile.meqrcode.cn/sync-v1/";
    private final Context context;
    private final I18n i18n;
    private final File secrets;
    ProfileSyncClient(Context c) { context=c.getApplicationContext(); i18n=new I18n(context); secrets=new File(context.getNoBackupFilesDir(),"profile-sync"); secrets.mkdirs(); }
    static final class Failure extends IOException {
        final int status;
        Failure(int status,String message) { super(message);this.status=status; }
    }
    private SecretKey key() throws Exception {
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");ks.load(null);
        String alias="meqr.profile-sync.v1";
        if (!ks.containsAlias(alias)) {
            KeyGenerator g=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
            g.init(new KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());g.generateKey();
        }
        return (SecretKey)ks.getKey(alias,null);
    }
    synchronized JSONObject secret(String id) throws Exception {
        AtomicFile file=new AtomicFile(new File(secrets,id));
        if (!file.getBaseFile().exists() && !new File(file.getBaseFile()+".bak").exists()) return null;
        byte[] bytes=file.readFully(); if(bytes.length<28) throw new IOException(i18n.t("syncErrCredentialCorrupt"));
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Arrays.copyOf(bytes,12)));
        c.updateAAD(id.getBytes(StandardCharsets.UTF_8));
        return new JSONObject(new String(c.doFinal(Arrays.copyOfRange(bytes,12,bytes.length)),StandardCharsets.UTF_8));
    }
    synchronized void saveSecret(String id,JSONObject value) throws Exception {
        AtomicFile file=new AtomicFile(new File(secrets,id));
        if (value==null) { file.delete();return; }
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key());c.updateAAD(id.getBytes(StandardCharsets.UTF_8));
        byte[] encrypted=c.doFinal(value.toString().getBytes(StandardCharsets.UTF_8));
        FileOutputStream out=null;
        try { out=file.startWrite();out.write(c.getIV());out.write(encrypted);file.finishWrite(out); }
        catch(Exception e) {if(out!=null)file.failWrite(out);throw e;}
    }
    static String token() {byte[] b=new byte[32];new SecureRandom().nextBytes(b);return hex(b);}
    static String hex(byte[] bytes) {StringBuilder s=new StringBuilder();for(byte b:bytes)s.append(String.format(Locale.ROOT,"%02x",b&255));return s.toString();}
    static String hash(byte[] bytes) throws Exception {return hex(MessageDigest.getInstance("SHA-256").digest(bytes));}
    static JSONObject json(Object... pairs) throws Exception {JSONObject o=new JSONObject();for(int i=0;i<pairs.length;i+=2)o.put((String)pairs[i],pairs[i+1]);return o;}
    byte[] request(String path,String method,String token,byte[] body,boolean binary) throws Exception {
        HttpURLConnection conn=(HttpURLConnection)new URL(ENDPOINT+path).openConnection();
        conn.setInstanceFollowRedirects(false);conn.setConnectTimeout(15000);conn.setReadTimeout(30000);conn.setRequestMethod(method);
        conn.setRequestProperty("Authorization","Bearer "+token);conn.setRequestProperty("Cache-Control","no-store");
        conn.setRequestProperty("Content-Type",binary?"application/octet-stream":"application/json");
        try {
            if(body!=null){conn.setDoOutput(true);conn.setFixedLengthStreamingMode(body.length);try(OutputStream out=conn.getOutputStream()){out.write(body);}}
            int status=conn.getResponseCode();
            byte[] data;
            try(InputStream in=status==200?conn.getInputStream():conn.getErrorStream()) {data=read(in,6*1024*1024);}
            if(status!=200){throw new Failure(status,statusError(status));}
            return data;
        } finally {conn.disconnect();}
    }
    private String statusError(int status) {
        switch(status) {
            case 401: case 403: return i18n.t("syncErrAuthorization");
            case 404: return i18n.t("syncErrNotFound");
            default: return i18n.tf("syncErrUnavailable",status);
        }
    }
    byte[] read(InputStream in,int limit) throws IOException {
        if(in==null)return new byte[0];ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[16384];int n;
        while((n=in.read(buffer))!=-1){if(out.size()+n>limit)throw new IOException(i18n.t("syncErrResponseLarge"));out.write(buffer,0,n);}return out.toByteArray();
    }
    JSONObject api(String path,String method,String token,JSONObject body) throws Exception {
        return new JSONObject(new String(request(path,method,token,body==null?null:body.toString().getBytes(StandardCharsets.UTF_8),false),StandardCharsets.UTF_8));
    }
    static String path(JSONObject b) throws Exception {return "profiles/"+b.getString("profileId");}
    static String deviceName() {return Build.MANUFACTURER+" "+Build.MODEL;}
    Map<String,byte[]> images(MeQrProfile p) throws Exception {
        Map<String,byte[]> result=new TreeMap<>();String[] kinds={"avatar","background","banner"},paths={p.avatarPath,p.backgroundPath,p.bannerPath};
        for(int i=0;i<kinds.length;i++) {
            if(paths[i]==null||paths[i].isEmpty())continue;
            File f=new File(paths[i]);int limit=(i==0?1:5)*1024*1024;
            byte[] data=null;
            if(f.length()<=limit) {try(InputStream in=new FileInputStream(f)){data=read(in,limit);}}
            boolean supported=data!=null&&data.length>4&&((data[0]==(byte)0xff&&data[1]==(byte)0xd8)||(data[0]==(byte)0x89&&data[1]==0x50&&data[2]==0x4e&&data[3]==0x47));
            if(!supported) {
                BitmapFactory.Options opts=new BitmapFactory.Options();opts.inJustDecodeBounds=true;BitmapFactory.decodeFile(paths[i],opts);
                opts.inJustDecodeBounds=false;opts.inSampleSize=1;while(Math.max(opts.outWidth,opts.outHeight)/opts.inSampleSize>2560)opts.inSampleSize*=2;
                Bitmap bitmap=BitmapFactory.decodeFile(paths[i],opts);if(bitmap==null)throw new IOException(i18n.t("syncErrImageRead"));
                try{ByteArrayOutputStream out=new ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.JPEG,85,out);data=out.toByteArray();}finally{bitmap.recycle();}
            }
            if(data.length>limit)throw new IOException(i18n.t("syncErrImageLarge"));result.put(kinds[i],data);
        }
        return result;
    }
    static JSONObject document(MeQrProfile p,Map<String,byte[]> images) throws Exception {
        JSONArray items=new JSONArray(),tags=new JSONArray();
        for(MeQrItem item:p.qrItems) items.put(json("platform",item.platform,"customPlatformName",item.customPlatformName,"qrContent",item.qrContent));
        for(String name:p.tags) {
            TagReference ref=p.referenceFor(name);if(ref==null)ref=new TagReference(name);
            JSONArray colors=new JSONArray(),palette=new JSONArray();for(int color:p.tagColors(name))colors.put(CardTagColorPalette.hex(color));for(int color:ref.colors)palette.put(CardTagColorPalette.hex(color));
            JSONObject tag = json("name",ref.fallbackName,"catalogID",ref.catalogID,"mode",ref.modeFor(p.tagColorOverrides.get(name)),"colors",colors,"presetColors",palette,"solidColor",CardTagColorPalette.hex(ref.solid),"weight",p.tagTextWeight(name));
            if (ref.pairing != null) tag.put("pairing", ref.pairing.toJson());
            tags.put(tag);
        }
        JSONObject assets=new JSONObject();for(Map.Entry<String,byte[]> e:images.entrySet())assets.put(e.getKey(),hash(e.getValue()));
        return json("schemaVersion",1,"name",p.name,"subtitle",p.subtitle,"passSubtitle",p.passSubtitle,"template","rhodes".equals(p.template)?"rhodesPass":p.template,
            "backgroundColor",p.backgroundColor,"borderColor",p.borderColor,"textColor",p.textColor,"qrColor",p.qrColor,"cornerRadius",p.cornerRadius,
            "cardOpacity",Double.parseDouble(Float.toString(p.cardOpacity)),"qrItems",items,"tags",tags,"assets",assets);
    }
    static boolean same(Object a,Object b) throws Exception {
        if(a==null||b==null)return a==b;
        if(a instanceof JSONObject && b instanceof JSONObject){JSONObject x=(JSONObject)a,y=(JSONObject)b;if(x.length()!=y.length())return false;Iterator<String> keys=x.keys();while(keys.hasNext()){String k=keys.next();if(!y.has(k)||!same(x.get(k),y.get(k)))return false;}return true;}
        if(a instanceof JSONArray && b instanceof JSONArray){JSONArray x=(JSONArray)a,y=(JSONArray)b;if(x.length()!=y.length())return false;for(int i=0;i<x.length();i++)if(!same(x.get(i),y.get(i)))return false;return true;}
        if(a instanceof Number && b instanceof Number)return Double.compare(((Number)a).doubleValue(),((Number)b).doubleValue())==0;
        return a.equals(b);
    }
    void upload(Map<String,byte[]> images,JSONObject b) throws Exception {
        for(byte[] data:images.values()) {
            JSONObject response=new JSONObject(new String(request(path(b)+"/assets","POST",b.getString("token"),data,true),StandardCharsets.UTF_8));
            if(!hash(data).equals(response.getString("hash")))throw new IOException(i18n.t("syncErrUploadVerify"));
        }
    }
    /** Download and validate everything before handing a new model to the caller for atomic persistence. */
    MeQrProfile apply(JSONObject snapshot,MeQrProfile original,String token) throws Exception {
        JSONObject doc=snapshot.getJSONObject("document");
        if(doc.getInt("schemaVersion")!=1||doc.getJSONArray("qrItems").length()==0)throw new IOException(i18n.t("syncErrFormatUnsupported"));
        MeQrProfile p=MeQrProfile.fromJson(original.toJson());
        JSONObject assets=doc.getJSONObject("assets");Map<String,String> paths=new HashMap<>();
        Iterator<String> keys=assets.keys();
        while(keys.hasNext()) {
            String kind=keys.next(),digest=assets.getString(kind);if(!digest.matches("[a-f0-9]{64}"))throw new IOException(i18n.t("syncErrImageIdInvalid"));
            byte[] bytes=request("profiles/"+snapshot.getString("profileId")+"/assets/"+digest,"GET",token,null,true);
            BitmapFactory.Options opts=new BitmapFactory.Options();opts.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,opts);
            if(!hash(bytes).equals(digest)||opts.outWidth<=0||opts.outHeight<=0||(long)opts.outWidth*opts.outHeight>25000000)throw new IOException(i18n.t("syncErrImageVerify"));
            File dir=new File(context.getFilesDir(),"images");dir.mkdirs();File f=new File(dir,"sync_"+digest);
            AtomicFile file=new AtomicFile(f);FileOutputStream out=null;
            try{out=file.startWrite();out.write(bytes);file.finishWrite(out);}catch(Exception e){if(out!=null)file.failWrite(out);throw e;}
            paths.put(kind,f.getAbsolutePath());
        }
        p.name=doc.getString("name");p.subtitle=doc.getString("subtitle");p.passSubtitle=doc.getString("passSubtitle");String template=doc.getString("template"); p.template=("rhodesPass".equals(template)||"rhodes".equals(template))?"rhodes":"standard";
        p.backgroundColor=doc.getString("backgroundColor");p.borderColor=doc.getString("borderColor");p.textColor=doc.getString("textColor");p.qrColor=doc.getString("qrColor");
        p.cornerRadius=doc.getInt("cornerRadius");p.cardOpacity=(float)doc.getDouble("cardOpacity");
        p.avatarPath=paths.getOrDefault("avatar","");p.backgroundPath=paths.getOrDefault("background","");p.bannerPath=paths.getOrDefault("banner","");
        List<MeQrItem> previous=new ArrayList<>(p.qrItems);p.qrItems.clear();JSONArray items=doc.getJSONArray("qrItems");
        for(int i=0;i<items.length();i++){MeQrItem item=MeQrItem.fromJson(items.getJSONObject(i));if(i<previous.size())item.id=previous.get(i).id;p.qrItems.add(item);}p.syncLegacyFields();
        p.tags.clear();p.tagColorOverrides.clear();p.tagTextWeights.clear();p.tagReferences.clear();JSONArray tags=doc.getJSONArray("tags");
        for(int i=0;i<tags.length();i++) {
            JSONObject tag=tags.getJSONObject(i);String name=tag.optString("name","");if(name.isEmpty())continue;p.tags.add(name);TagReference ref=new TagReference(name);ref.catalogID=tag.optString("catalogID","");
            JSONArray palette=tag.optJSONArray("presetColors");
            if(palette!=null&&palette.length()>0){ref.colors=new int[Math.min(6,palette.length())];for(int j=0;j<ref.colors.length;j++)ref.colors[j]=CardTagColorPalette.parseHex(palette.optString(j),0xff6f7582);}
            ref.solid=CardTagColorPalette.parseHex(tag.optString("solidColor",""),ref.colors[0]);String mode=tag.optString("mode","preset");
            if("custom".equals(mode)){JSONArray colors=tag.optJSONArray("colors");List<String> values=new ArrayList<>();if(colors!=null)for(int j=0;j<colors.length();j++)values.add(colors.optString(j));ref.override=values.isEmpty()?null:String.join("|",values);}
            else ref.override="solid".equals(mode)?"@solid":"@preset";
            ref.pairing = TagPair.fromJson(tag.optJSONObject("pairing"));
            ref.textWeight=TagTextWeight.normalize(tag.optInt("weight",TagTextWeight.REGULAR));p.tagReferences.add(ref);p.tagColorOverrides.put(name,ref.override);p.setTagTextWeight(name,ref.textWeight);
        }
        return p;
    }
    JSONObject create(MeQrProfile p) throws Exception {
        JSONObject pending=secret("create-"+p.id);if(pending==null){pending=json("token",token());saveSecret("create-"+p.id,pending);}
        String token=pending.getString("token");JSONObject doc=document(p,images(p));doc.put("assets",new JSONObject());
        JSONObject snapshot=api("profiles","POST",token,json("document",doc,"deviceName",deviceName()));
        JSONObject b=binding(snapshot,token);saveSecret(p.id,b);saveSecret("create-"+p.id,null);return b;
    }
    static JSONObject binding(JSONObject s,String token) throws Exception {return json("profileId",s.getString("profileId"),"deviceId",s.getString("deviceId"),"role",s.getString("role"),"revision",s.getInt("revision"),"token",token);}
    static final class Result {final MeQrProfile profile;final JSONObject binding;Result(MeQrProfile p,JSONObject b){profile=p;binding=b;}}
    Result sync(MeQrProfile p,String resolution) throws Exception {
        JSONObject b=secret(p.id);if(b==null)throw new IOException(i18n.t("syncErrNotEnabled"));
        JSONObject baseline=b.optJSONObject("baseline");
        if(baseline!=null&&"rhodes".equals(baseline.optString("template")))baseline.put("template","rhodesPass");
        Map<String,byte[]> images=images(p);JSONObject local=document(p,images),remote=api(path(b),"GET",b.getString("token"),null),remoteDoc=remote.getJSONObject("document");
        int revision=remote.getInt("revision");MeQrProfile updated=p;
        if("remote".equals(resolution)||(same(local,b.optJSONObject("baseline"))&&revision!=b.getInt("revision"))) {
            updated=apply(remote,p,b.getString("token"));b.put("baseline",document(updated,images(updated)));b.put("revision",revision);
        } else if(same(local,remoteDoc)) {b.put("baseline",local);b.put("revision",revision);}
        else if(!same(local,b.optJSONObject("baseline"))) {
            if(revision!=b.getInt("revision")&&!"local".equals(resolution))throw new Failure(409,i18n.t("syncConflictTitle"));
            upload(images,b);JSONObject saved=api(path(b),"PUT",b.getString("token"),json("document",local,"revision",revision));b.put("revision",saved.getInt("revision"));b.put("baseline",local);
        }
        return new Result(updated,b);
    }
}
