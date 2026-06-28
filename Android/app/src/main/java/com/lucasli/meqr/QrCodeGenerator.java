package com.lucasli.meqr;

import android.graphics.Bitmap;
import android.graphics.Color;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;

import java.util.EnumMap;
import java.util.Map;

final class QrCodeGenerator {
    private QrCodeGenerator() {
    }

    static Bitmap generate(String content, int foregroundColor, int size) {
        return generateInternal(content, foregroundColor, size, Color.WHITE);
    }

    static Bitmap generateTransparent(String content, int foregroundColor, int size) {
        return generateInternal(content, foregroundColor, size, Color.TRANSPARENT);
    }

    private static Bitmap generateInternal(String content, int foregroundColor, int size, int backgroundColor) {
        String value = content == null || content.trim().isEmpty() ? "MeQR" : content.trim();
        Map<EncodeHintType, Object> hints = new EnumMap<>(EncodeHintType.class);
        hints.put(EncodeHintType.MARGIN, 1);
        try {
            BitMatrix matrix = new QRCodeWriter().encode(value, BarcodeFormat.QR_CODE, size, size, hints);
            Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
            for (int y = 0; y < size; y++) {
                for (int x = 0; x < size; x++) {
                    bitmap.setPixel(x, y, matrix.get(x, y) ? foregroundColor : backgroundColor);
                }
            }
            return bitmap;
        } catch (WriterException exception) {
            Bitmap fallback = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
            fallback.eraseColor(backgroundColor);
            return fallback;
        }
    }
}
