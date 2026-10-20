package com.lucasli.meqr;

import android.app.Instrumentation;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.os.Bundle;
import com.google.zxing.Result;
import java.io.ByteArrayOutputStream;
import java.lang.reflect.Method;
import java.util.Arrays;

public final class ColorLayerInstrumentation extends Instrumentation {
    private boolean repairOnly;
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        repairOnly = arguments != null && "true".equals(arguments.getString("repairOnly"));
        start();
    }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".colortest"), "Isolated package");
            if (repairOnly) {
                verifyRepairedAvatar();
                result.putString("stream", "PASS real repaired iOS avatar CRC and JPEG decode\n");
                finish(-1, result);
                return;
            }
            Bitmap portrait = Bitmap.createBitmap(20, 20, Bitmap.Config.ARGB_8888);
            portrait.eraseColor(Color.rgb(40, 130, 200));
            ByteArrayOutputStream jpeg = new ByteArrayOutputStream();
            portrait.compress(Bitmap.CompressFormat.JPEG, 50, jpeg);
            byte[] avatar = jpeg.toByteArray();
            Method packetMethod = MeQrColorLayer.class.getDeclaredMethod("packet", byte[].class, int.class);
            Method symbolsMethod = MeQrColorLayer.class.getDeclaredMethod("encodeSymbols", byte[].class, int.class);
            Method parseMethod = MeQrColorLayer.class.getDeclaredMethod("parse", int[].class);
            packetMethod.setAccessible(true); symbolsMethod.setAccessible(true); parseMethod.setAccessible(true);
            byte[] packet = (byte[]) packetMethod.invoke(null, avatar, 1);
            int count = ((packet.length * 4 + 2) / 3) * 5;
            int[] symbols = (int[]) symbolsMethod.invoke(null, packet, count);
            symbols[85] ^= 1;
            check(Arrays.equals(avatar, (byte[]) parseMethod.invoke(null, symbols)), "single symbol corrected");
            packet[packet.length - 1] ^= 1;
            int[] corrupted = (int[]) symbolsMethod.invoke(null, packet, count);
            check(parseMethod.invoke(null, corrupted) == null, "CRC rejects damaged avatar");
            String payload = MeQrColorLayer.paddedContent("meqr://profile/color-test", Math.max(800, avatar.length));
            Bitmap code = MeQrColorLayer.generate(payload, avatar, 1000);
            verify(code, payload, avatar, "new palette");
            Bitmap legacy = code.copy(Bitmap.Config.ARGB_8888, true);
            int[] current = {Color.rgb(153,188,255), Color.rgb(153,240,224), Color.rgb(255,163,201), Color.rgb(204,163,245)};
            int[] previous = {Color.rgb(168,207,255), Color.rgb(158,230,214), Color.rgb(255,194,212), Color.rgb(214,184,255)};
            int[] pixels = new int[1000000];
            legacy.getPixels(pixels, 0, 1000, 0, 0, 1000, 1000);
            for (int index = 0; index < pixels.length; index++) {
                for (int symbol = 0; symbol < 4; symbol++) {
                    if (pixels[index] == current[symbol]) { pixels[index] = previous[symbol]; break; }
                }
            }
            legacy.setPixels(pixels, 0, 1000, 0, 0, 1000, 1000);
            verify(legacy, payload, avatar, "legacy palette");
            try (java.io.FileOutputStream stream = new java.io.FileOutputStream(new java.io.File(getTargetContext().getFilesDir(), "android-legacy.png"))) { legacy.compress(Bitmap.CompressFormat.PNG, 100, stream); }
            String fixturePath = "/data/local/tmp/meqr-ios-color.png";
            Bitmap ios = android.graphics.BitmapFactory.decodeFile(fixturePath);
            if (ios != null) {
                String iosPayload = new String(java.nio.file.Files.readAllBytes(java.nio.file.Paths.get("/data/local/tmp/meqr-ios-payload.txt")), java.nio.charset.StandardCharsets.UTF_8);
                verify(ios, iosPayload, avatar, "iOS generated color code");
                android.util.Log.i("ColorLayerTest", "PASS iOS to Android avatar CRC");
            }
            Bitmap repaired = android.graphics.BitmapFactory.decodeFile("/data/local/tmp/meqr-repaired-code.png");
            if (repaired != null) {
                repaired.recycle();
                verifyRepairedAvatar();
            }
            for (int angle : new int[]{90, 180, 270}) {
                Matrix rotation = new Matrix(); rotation.postRotate(angle);
                verify(Bitmap.createBitmap(code, 0, 0, 1000, 1000, rotation, false), payload, avatar, "rotation " + angle);
            }
            Matrix mirror = new Matrix(); mirror.setScale(-1, 1);
            verify(Bitmap.createBitmap(code, 0, 0, 1000, 1000, mirror, false), payload, avatar, "mirror");
            Bitmap large = Bitmap.createBitmap(3000, 3600, Bitmap.Config.ARGB_8888);
            large.eraseColor(Color.WHITE);
            new Canvas(large).drawBitmap(code, 700, 1300, null);
            verify(large, payload, avatar, "resized image coordinates");
            Method region = QrImageDecoder.class.getDeclaredMethod("decodeBitmapRegion", Bitmap.class, int.class, int.class, int.class, int.class, int.class);
            region.setAccessible(true);
            Result cropped = (Result) region.invoke(null, large, 600, 1200, 1200, 1200, 900);
            check(cropped != null && Arrays.equals(avatar, MeQrColorLayer.decode(large, cropped)), "crop and scale coordinates");
            Bitmap mono = MeQrColorLayer.generate(payload, null, 1000);
            verify(mono, payload, null, "no avatar fallback");
            int[] monoPixels = new int[1000000];
            mono.getPixels(monoPixels, 0, 1000, 0, 0, 1000, 1000);
            for (int pixel : monoPixels) check(pixel == Color.BLACK || pixel == Color.WHITE, "no decorative color without data");
            java.io.File output = new java.io.File(getTargetContext().getFilesDir(), "android-color.png");
            try (java.io.FileOutputStream stream = new java.io.FileOutputStream(output)) { code.compress(Bitmap.CompressFormat.PNG, 100, stream); }
            try (java.io.FileOutputStream stream = new java.io.FileOutputStream(new java.io.File(getTargetContext().getFilesDir(), "avatar.jpg"))) { stream.write(avatar); }
            result.putString("stream", "PASS new/legacy palette, rotations/mirror, scale/crop coordinates, mono fallback\n");
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error)); finish(1, result);
        }
    }
    private static void verifyRepairedAvatar() throws Exception {
        Bitmap repaired = android.graphics.BitmapFactory.decodeFile("/data/local/tmp/meqr-repaired-code.png");
        check(repaired != null, "real repaired iOS code fixture required");
        byte[] repairedAvatar = java.nio.file.Files.readAllBytes(java.nio.file.Paths.get("/data/local/tmp/meqr-repaired-avatar.jpg"));
        verify(repaired, QrImageDecoder.decode(repaired).getText(), repairedAvatar, "real repaired iOS avatar");
        check(android.graphics.BitmapFactory.decodeByteArray(repairedAvatar, 0, repairedAvatar.length) != null, "compact JPEG decodes on Android");
        android.util.Log.i("ColorLayerTest", "PASS real repaired iOS avatar CRC and JPEG decode");
    }

    private static void verify(Bitmap image, String payload, byte[] avatar, String label) throws Exception {
        Result decoded = QrImageDecoder.decode(image);
        check(payload.equals(decoded.getText()), label + " base QR");
        check(Arrays.equals(avatar, MeQrColorLayer.decode(image, decoded)), label + " avatar CRC");
    }
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
