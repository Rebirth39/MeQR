package com.lucasli.meqr;

import android.graphics.Bitmap;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.DecodeHintType;
import com.google.zxing.LuminanceSource;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.NotFoundException;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.Result;
import com.google.zxing.common.GlobalHistogramBinarizer;
import com.google.zxing.common.HybridBinarizer;

import java.util.Collections;
import java.util.EnumMap;
import java.util.Map;

final class QrImageDecoder {
    private static final int MAX_FULL_IMAGE_EDGE = 2400;
    private static final int MAX_REGION_EDGE = 1800;
    private static final Map<DecodeHintType, Object> HINTS = createHints(false);
    private static final Map<DecodeHintType, Object> PURE_HINTS = createHints(true);

    private QrImageDecoder() {
    }

    static Result decode(Bitmap bitmap) throws NotFoundException {
        if (bitmap == null || bitmap.getWidth() < 16 || bitmap.getHeight() < 16) {
            throw NotFoundException.getNotFoundInstance();
        }

        Result result = decodeBitmapRegion(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), MAX_FULL_IMAGE_EDGE);
        if (result != null) {
            return result;
        }

        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        int shortEdge = Math.min(width, height);
        if (height > width * 1.15f) {
            int middleTop = Math.max(0, (height - width) / 2);
            int bottomTop = Math.max(0, height - width);
            result = firstResult(
                    decodeBitmapRegion(bitmap, 0, 0, width, Math.min(width, height), MAX_REGION_EDGE),
                    decodeBitmapRegion(bitmap, 0, middleTop, width, Math.min(width, height - middleTop), MAX_REGION_EDGE),
                    decodeBitmapRegion(bitmap, 0, bottomTop, width, Math.min(width, height - bottomTop), MAX_REGION_EDGE)
            );
        } else if (width > height * 1.15f) {
            int middleLeft = Math.max(0, (width - height) / 2);
            int rightLeft = Math.max(0, width - height);
            result = firstResult(
                    decodeBitmapRegion(bitmap, 0, 0, Math.min(height, width), height, MAX_REGION_EDGE),
                    decodeBitmapRegion(bitmap, middleLeft, 0, Math.min(height, width - middleLeft), height, MAX_REGION_EDGE),
                    decodeBitmapRegion(bitmap, rightLeft, 0, Math.min(height, width - rightLeft), height, MAX_REGION_EDGE)
            );
        }
        if (result != null) {
            return result;
        }

        for (float fraction : new float[]{0.78f, 0.58f, 0.42f}) {
            int size = Math.max(16, Math.round(shortEdge * fraction));
            int left = Math.max(0, (width - size) / 2);
            int top = Math.max(0, (height - size) / 2);
            result = decodeBitmapRegion(bitmap, left, top, size, size, MAX_REGION_EDGE);
            if (result != null) {
                return result;
            }
        }
        throw NotFoundException.getNotFoundInstance();
    }

    static Result decode(LuminanceSource source) throws NotFoundException {
        Result result = decodeSource(source);
        if (result != null) {
            return result;
        }
        if (source.isCropSupported()) {
            int size = Math.min(source.getWidth(), source.getHeight());
            int left = Math.max(0, (source.getWidth() - size) / 2);
            int top = Math.max(0, (source.getHeight() - size) / 2);
            result = decodeSource(source.crop(left, top, size, size));
            if (result != null) {
                return result;
            }
        }
        throw NotFoundException.getNotFoundInstance();
    }

    private static Result decodeBitmapRegion(Bitmap bitmap, int left, int top, int width, int height, int maxEdge) {
        if (width < 16 || height < 16) {
            return null;
        }
        Bitmap region = Bitmap.createBitmap(bitmap, left, top, width, height);
        Bitmap candidate = scaleDown(region, maxEdge);
        try {
            int candidateWidth = candidate.getWidth();
            int candidateHeight = candidate.getHeight();
            int[] pixels = new int[candidateWidth * candidateHeight];
            candidate.getPixels(pixels, 0, candidateWidth, 0, 0, candidateWidth, candidateHeight);
            return decodeSource(new RGBLuminanceSource(candidateWidth, candidateHeight, pixels));
        } finally {
            if (candidate != region && candidate != bitmap) {
                candidate.recycle();
            }
            if (region != bitmap) {
                region.recycle();
            }
        }
    }

    private static Bitmap scaleDown(Bitmap bitmap, int maxEdge) {
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        int largest = Math.max(width, height);
        if (largest <= maxEdge) {
            return bitmap;
        }
        float scale = maxEdge / (float) largest;
        return Bitmap.createScaledBitmap(
                bitmap,
                Math.max(1, Math.round(width * scale)),
                Math.max(1, Math.round(height * scale)),
                true
        );
    }

    private static Result decodeSource(LuminanceSource source) {
        Result result = decodeBinary(new BinaryBitmap(new HybridBinarizer(source)), HINTS);
        if (result != null) {
            return result;
        }
        result = decodeBinary(new BinaryBitmap(new GlobalHistogramBinarizer(source)), HINTS);
        if (result != null) {
            return result;
        }
        LuminanceSource inverted = source.invert();
        result = decodeBinary(new BinaryBitmap(new HybridBinarizer(inverted)), HINTS);
        if (result != null) {
            return result;
        }
        LuminanceSource padded = new PaddedLuminanceSource(source);
        result = decodeBinary(new BinaryBitmap(new HybridBinarizer(padded)), HINTS);
        if (result != null) {
            return result;
        }
        return decodeBinary(new BinaryBitmap(new HybridBinarizer(padded)), PURE_HINTS);
    }

    private static Result decodeBinary(BinaryBitmap bitmap, Map<DecodeHintType, Object> hints) {
        MultiFormatReader reader = new MultiFormatReader();
        try {
            return reader.decode(bitmap, hints);
        } catch (NotFoundException exception) {
            return null;
        } finally {
            reader.reset();
        }
    }

    private static Result firstResult(Result... results) {
        for (Result result : results) {
            if (result != null) {
                return result;
            }
        }
        return null;
    }

    private static Map<DecodeHintType, Object> createHints(boolean pureBarcode) {
        Map<DecodeHintType, Object> hints = new EnumMap<>(DecodeHintType.class);
        hints.put(DecodeHintType.POSSIBLE_FORMATS, Collections.singletonList(BarcodeFormat.QR_CODE));
        hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
        hints.put(DecodeHintType.ALSO_INVERTED, Boolean.TRUE);
        hints.put(DecodeHintType.CHARACTER_SET, "UTF-8");
        if (pureBarcode) {
            hints.put(DecodeHintType.PURE_BARCODE, Boolean.TRUE);
        }
        return Collections.unmodifiableMap(hints);
    }

    private static final class PaddedLuminanceSource extends LuminanceSource {
        private final byte[] matrix;

        PaddedLuminanceSource(LuminanceSource source) {
            super(source.getWidth() + border(source) * 2, source.getHeight() + border(source) * 2);
            int border = border(source);
            int width = getWidth();
            int height = getHeight();
            matrix = new byte[width * height];
            java.util.Arrays.fill(matrix, (byte) 0xFF);
            byte[] original = source.getMatrix();
            for (int row = 0; row < source.getHeight(); row++) {
                System.arraycopy(
                        original,
                        row * source.getWidth(),
                        matrix,
                        (row + border) * width + border,
                        source.getWidth()
                );
            }
        }

        @Override
        public byte[] getRow(int row, byte[] target) {
            if (row < 0 || row >= getHeight()) {
                throw new IllegalArgumentException("Requested row is outside the image");
            }
            if (target == null || target.length < getWidth()) {
                target = new byte[getWidth()];
            }
            System.arraycopy(matrix, row * getWidth(), target, 0, getWidth());
            return target;
        }

        @Override
        public byte[] getMatrix() {
            return matrix;
        }

        private static int border(LuminanceSource source) {
            return Math.max(16, Math.min(source.getWidth(), source.getHeight()) / 24);
        }
    }
}
