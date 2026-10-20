package com.lucasli.meqr;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Base64;

import java.io.ByteArrayOutputStream;

final class MeQrAvatarThumbnail {
    private static final int SIDE = 12;
    private static final byte[] MAGIC = new byte[]{0x4D, 0x51, 0x54, 0x31};

    private MeQrAvatarThumbnail() {
    }

    static String encodeBase64(String path) {
        if (path == null || path.trim().isEmpty()) return "";
        Bitmap source = BitmapFactory.decodeFile(path);
        if (source == null || source.getWidth() <= 0 || source.getHeight() <= 0) return "";
        Bitmap square = null;
        Bitmap scaled = null;
        try {
            int size = Math.min(source.getWidth(), source.getHeight());
            square = Bitmap.createBitmap(source, (source.getWidth() - size) / 2,
                    (source.getHeight() - size) / 2, size, size);
            scaled = Bitmap.createScaledBitmap(square, SIDE, SIDE, true);
            int[] pixels = new int[SIDE * SIDE];
            scaled.getPixels(pixels, 0, SIDE, 0, 0, SIDE, SIDE);
            byte[] packet = new byte[6 + pixels.length];
            System.arraycopy(MAGIC, 0, packet, 0, MAGIC.length);
            packet[4] = (byte) SIDE;
            packet[5] = (byte) SIDE;
            for (int index = 0; index < pixels.length; index++) {
                int color = pixels[index];
                int red = (color >> 16) & 0xff;
                int green = (color >> 8) & 0xff;
                int blue = color & 0xff;
                packet[6 + index] = (byte) ((red & 0xe0) | ((green >> 3) & 0x1c) | (blue >> 6));
            }
            return Base64.encodeToString(packet, Base64.NO_WRAP);
        } finally {
            if (scaled != null && scaled != square) scaled.recycle();
            if (square != null && square != source) square.recycle();
            source.recycle();
        }
    }

    static String decodeToJpegBase64(String encoded) {
        if (encoded == null || encoded.isEmpty()) return "";
        byte[] packet;
        try {
            packet = Base64.decode(encoded, Base64.DEFAULT);
        } catch (IllegalArgumentException exception) {
            return "";
        }
        if (packet.length != 6 + SIDE * SIDE
                || packet[0] != MAGIC[0] || packet[1] != MAGIC[1]
                || packet[2] != MAGIC[2] || packet[3] != MAGIC[3]
                || packet[4] != SIDE || packet[5] != SIDE) {
            return "";
        }
        int[] pixels = new int[SIDE * SIDE];
        for (int index = 0; index < pixels.length; index++) {
            int value = packet[6 + index] & 0xff;
            int red = (value & 0xe0) | ((value & 0xe0) >> 3) | ((value & 0xe0) >> 6);
            int green = ((value & 0x1c) << 3) | ((value & 0x1c) >> 2) | ((value & 0x1c) >> 7);
            int blue = (value & 0x03) * 0x55;
            pixels[index] = 0xff000000 | (red << 16) | (green << 8) | blue;
        }
        Bitmap bitmap = Bitmap.createBitmap(pixels, SIDE, SIDE, Bitmap.Config.ARGB_8888);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 72, output)) return "";
            return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP);
        } finally {
            bitmap.recycle();
        }
    }
}
