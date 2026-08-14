package com.lucasli.meqr;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.Image;

import com.google.zxing.Result;
import com.google.zxing.ResultPoint;
import com.google.zxing.common.PerspectiveTransform;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import com.google.zxing.qrcode.encoder.ByteMatrix;
import com.google.zxing.qrcode.encoder.Encoder;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.zip.CRC32;

final class MeQrColorLayer {
    private static final byte[] MAGIC = new byte[]{0x4D, 0x43, 0x51, 0x52};
    private static final int VERSION = 1;
    private static final int AVATAR_JPEG_TYPE = 1;
    private static final int HEADER_BYTES = 12;
    private static final int QUIET_ZONE = 4;
    private static final int[] DARK_PALETTE = new int[]{
            Color.rgb(18, 51, 120),
            Color.rgb(5, 97, 84),
            Color.rgb(112, 20, 64),
            Color.rgb(74, 31, 128)
    };
    private static final int[] LIGHT_PALETTE = new int[]{
            Color.rgb(191, 217, 255),
            Color.rgb(184, 242, 232),
            Color.rgb(255, 204, 222),
            Color.rgb(227, 204, 255)
    };
    private static final float[] TARGET_HUES = new float[]{219.6f, 169.2f, 334.8f, 270.0f};

    private MeQrColorLayer() {
    }

    static int payloadCapacity(String content) {
        ByteMatrix matrix = matrix(content);
        if (matrix == null) {
            return 0;
        }
        int moduleCount = matrix.getWidth() * matrix.getHeight();
        int decodedBytes = ((moduleCount / 5) * 3) / 4;
        return Math.max(decodedBytes - HEADER_BYTES, 0);
    }

    static String paddedContent(String content, int minimumPayloadCapacity) {
        String value = content == null ? "" : content;
        if (payloadCapacity(value) >= minimumPayloadCapacity) {
            return value;
        }
        int fragmentIndex = value.indexOf('#');
        String prefix = fragmentIndex >= 0 ? value.substring(0, fragmentIndex) : value;
        String fragment = fragmentIndex >= 0 ? value.substring(fragmentIndex) : "";
        String paddingPrefix = prefix + (prefix.contains("?") ? "&" : "?") + "mcqr=";
        String bestCandidate = value;
        StringBuilder padding = new StringBuilder(1600);
        for (int length = 64; length <= 1600; length += 64) {
            while (padding.length() < length) {
                padding.append('A');
            }
            String candidate = paddingPrefix + padding + fragment;
            bestCandidate = candidate;
            if (payloadCapacity(candidate) >= minimumPayloadCapacity) {
                return candidate;
            }
        }
        return bestCandidate;
    }

    static Bitmap generate(String content, byte[] avatarJpeg, int size) {
        ByteMatrix matrix = matrix(content);
        if (matrix == null || avatarJpeg == null || avatarJpeg.length == 0
                || avatarJpeg.length > payloadCapacity(content)) {
            return null;
        }
        byte[] packet = packet(avatarJpeg, AVATAR_JPEG_TYPE);
        if (packet == null) {
            return null;
        }
        int dimension = matrix.getWidth();
        int fullDimension = dimension + QUIET_ZONE * 2;
        int scale = Math.max(1, size / fullDimension);
        int renderedSize = fullDimension * scale;
        int offset = Math.max(0, (size - renderedSize) / 2);
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        bitmap.eraseColor(Color.WHITE);
        int[] symbols = encodeSymbols(packet, dimension * dimension);
        for (int row = 0; row < dimension; row++) {
            for (int column = 0; column < dimension; column++) {
                int symbol = symbols[row * dimension + column];
                int color = matrix.get(column, row) == 1 ? DARK_PALETTE[symbol] : LIGHT_PALETTE[symbol];
                int left = offset + (column + QUIET_ZONE) * scale;
                int top = offset + (row + QUIET_ZONE) * scale;
                for (int y = top; y < top + scale; y++) {
                    for (int x = left; x < left + scale; x++) {
                        bitmap.setPixel(x, y, color);
                    }
                }
            }
        }
        return bitmap;
    }

    static byte[] decode(Bitmap bitmap, Result result) {
        if (bitmap == null) {
            return null;
        }
        return decode(new BitmapPixels(bitmap), result);
    }

    static byte[] decode(Image image, Result result) {
        if (image == null || image.getPlanes().length < 3) {
            return null;
        }
        return decode(new YuvPixels(image), result);
    }

    private static byte[] decode(PixelSource source, Result result) {
        if (result == null || result.getText() == null) {
            return null;
        }
        ByteMatrix matrix = matrix(result.getText());
        ResultPoint[] resultPoints = result.getResultPoints();
        if (matrix == null || resultPoints == null || resultPoints.length < 3) {
            return null;
        }
        int preferredDimension = matrix.getWidth();
        int[] candidateDimensions = new int[40];
        candidateDimensions[0] = preferredDimension;
        int candidateIndex = 1;
        for (int version = 1; version <= 40; version++) {
            int dimension = 17 + version * 4;
            if (dimension != preferredDimension) {
                candidateDimensions[candidateIndex++] = dimension;
            }
        }
        for (int dimension : candidateDimensions) {
            PerspectiveTransform transform = transform(dimension, resultPoints);
            if (transform == null) {
                continue;
            }
            float[] points = new float[dimension * dimension * 2];
            int pointIndex = 0;
            for (int row = 0; row < dimension; row++) {
                for (int column = 0; column < dimension; column++) {
                    points[pointIndex++] = column + 0.5f;
                    points[pointIndex++] = row + 0.5f;
                }
            }
            transform.transformPoints(points);
            int[] symbols = new int[dimension * dimension];
            for (int index = 0; index < symbols.length; index++) {
                int color = source.colorAt(points[index * 2], points[index * 2 + 1]);
                symbols[index] = nearestSymbol(color);
            }
            for (boolean mirrored : new boolean[]{false, true}) {
                for (int rotation = 0; rotation < 4; rotation++) {
                    byte[] avatar = parse(transformed(symbols, dimension, rotation, mirrored));
                    if (avatar != null) {
                        return avatar;
                    }
                }
            }
        }
        return null;
    }

    private static PerspectiveTransform transform(int dimension, ResultPoint[] points) {
        ResultPoint bottomLeft = points[0];
        ResultPoint topLeft = points[1];
        ResultPoint topRight = points[2];
        float sourceBottomRight = dimension - 3.5f;
        float targetBottomRightX;
        float targetBottomRightY;
        if (points.length >= 4 && points[3] != null) {
            sourceBottomRight -= 3.0f;
            targetBottomRightX = points[3].getX();
            targetBottomRightY = points[3].getY();
        } else {
            targetBottomRightX = topRight.getX() - topLeft.getX() + bottomLeft.getX();
            targetBottomRightY = topRight.getY() - topLeft.getY() + bottomLeft.getY();
        }
        return PerspectiveTransform.quadrilateralToQuadrilateral(
                3.5f, 3.5f,
                dimension - 3.5f, 3.5f,
                sourceBottomRight, sourceBottomRight,
                3.5f, dimension - 3.5f,
                topLeft.getX(), topLeft.getY(),
                topRight.getX(), topRight.getY(),
                targetBottomRightX, targetBottomRightY,
                bottomLeft.getX(), bottomLeft.getY()
        );
    }

    private static ByteMatrix matrix(String content) {
        String value = content == null || content.trim().isEmpty() ? "MeQR" : content.trim();
        try {
            return Encoder.encode(value, ErrorCorrectionLevel.M).getMatrix();
        } catch (Exception exception) {
            return null;
        }
    }

    private static byte[] packet(byte[] payload, int type) {
        if (payload.length > 0xFFFF) {
            return null;
        }
        CRC32 crc = new CRC32();
        crc.update(payload);
        long checksum = crc.getValue();
        ByteArrayOutputStream output = new ByteArrayOutputStream(HEADER_BYTES + payload.length);
        output.write(MAGIC, 0, MAGIC.length);
        output.write(VERSION);
        output.write(type);
        output.write((payload.length >>> 8) & 0xFF);
        output.write(payload.length & 0xFF);
        output.write((int) ((checksum >>> 24) & 0xFF));
        output.write((int) ((checksum >>> 16) & 0xFF));
        output.write((int) ((checksum >>> 8) & 0xFF));
        output.write((int) (checksum & 0xFF));
        output.write(payload, 0, payload.length);
        return output.toByteArray();
    }

    private static int[] encodeSymbols(byte[] packet, int count) {
        int[] raw = new int[((packet.length * 4 + 2) / 3) * 3];
        int rawIndex = 0;
        for (byte value : packet) {
            int unsigned = value & 0xFF;
            raw[rawIndex++] = (unsigned >>> 6) & 0x03;
            raw[rawIndex++] = (unsigned >>> 4) & 0x03;
            raw[rawIndex++] = (unsigned >>> 2) & 0x03;
            raw[rawIndex++] = unsigned & 0x03;
        }
        int[] symbols = new int[count];
        int symbolIndex = 0;
        for (int index = 0; index < raw.length && symbolIndex + 4 < count; index += 3) {
            int[] encoded = encodeFec(raw[index], raw[index + 1], raw[index + 2]);
            for (int value : encoded) {
                symbols[symbolIndex++] = value;
            }
        }
        while (symbolIndex < count) {
            symbols[symbolIndex] = symbolIndex & 0x03;
            symbolIndex++;
        }
        return symbols;
    }

    private static byte[] parse(int[] symbols) {
        int groupCount = symbols.length / 5;
        int[] decoded = new int[groupCount * 3];
        int decodedIndex = 0;
        for (int group = 0; group < groupCount; group++) {
            int[] values = Arrays.copyOfRange(symbols, group * 5, group * 5 + 5);
            int[] data = decodeFec(values);
            if (data == null) {
                return null;
            }
            decoded[decodedIndex++] = data[0];
            decoded[decodedIndex++] = data[1];
            decoded[decodedIndex++] = data[2];
        }
        byte[] bytes = new byte[decoded.length / 4];
        for (int index = 0; index < bytes.length; index++) {
            int offset = index * 4;
            bytes[index] = (byte) ((decoded[offset] << 6)
                    | (decoded[offset + 1] << 4)
                    | (decoded[offset + 2] << 2)
                    | decoded[offset + 3]);
        }
        if (bytes.length < HEADER_BYTES
                || !Arrays.equals(Arrays.copyOfRange(bytes, 0, 4), MAGIC)
                || (bytes[4] & 0xFF) != VERSION
                || (bytes[5] & 0xFF) != AVATAR_JPEG_TYPE) {
            return null;
        }
        int length = ((bytes[6] & 0xFF) << 8) | (bytes[7] & 0xFF);
        if (length <= 0 || HEADER_BYTES + length > bytes.length) {
            return null;
        }
        long expected = ((long) (bytes[8] & 0xFF) << 24)
                | ((long) (bytes[9] & 0xFF) << 16)
                | ((long) (bytes[10] & 0xFF) << 8)
                | (long) (bytes[11] & 0xFF);
        byte[] payload = Arrays.copyOfRange(bytes, HEADER_BYTES, HEADER_BYTES + length);
        CRC32 crc = new CRC32();
        crc.update(payload);
        return crc.getValue() == expected ? payload : null;
    }

    private static int[] encodeFec(int first, int second, int third) {
        int parityBase = first ^ third;
        int fifth = second ^ third ^ multiplyGf4(2, parityBase);
        int fourth = parityBase ^ fifth;
        return new int[]{first, second, third, fourth, fifth};
    }

    private static int[] decodeFec(int[] values) {
        int[] corrected = values.clone();
        for (int index = 0; index < corrected.length; index++) {
            corrected[index] &= 0x03;
        }
        int first = corrected[0] ^ corrected[2] ^ corrected[3] ^ corrected[4];
        int second = corrected[1] ^ corrected[2]
                ^ multiplyGf4(2, corrected[3]) ^ multiplyGf4(3, corrected[4]);
        if (first != 0 || second != 0) {
            int errorIndex;
            int magnitude;
            if (second == 0) {
                errorIndex = 0;
                magnitude = first;
            } else if (first == 0) {
                errorIndex = 1;
                magnitude = second;
            } else if (second == first) {
                errorIndex = 2;
                magnitude = first;
            } else if (second == multiplyGf4(2, first)) {
                errorIndex = 3;
                magnitude = first;
            } else if (second == multiplyGf4(3, first)) {
                errorIndex = 4;
                magnitude = first;
            } else {
                return null;
            }
            corrected[errorIndex] ^= magnitude;
        }
        return new int[]{corrected[0], corrected[1], corrected[2]};
    }

    private static int multiplyGf4(int left, int right) {
        left &= 0x03;
        right &= 0x03;
        if (left == 0 || right == 0) {
            return 0;
        }
        if (left == 1) {
            return right;
        }
        if (right == 1) {
            return left;
        }
        if (left == 2 && right == 2) {
            return 3;
        }
        if (left == 3 && right == 3) {
            return 2;
        }
        return 1;
    }

    private static int[] transformed(int[] symbols, int side, int rotation, boolean mirrored) {
        int[] transformed = new int[symbols.length];
        for (int index = 0; index < symbols.length; index++) {
            int row = index / side;
            int column = index % side;
            for (int turn = 0; turn < rotation; turn++) {
                int oldRow = row;
                row = side - column - 1;
                column = oldRow;
            }
            if (mirrored) {
                column = side - column - 1;
            }
            transformed[index] = symbols[row * side + column];
        }
        return transformed;
    }

    private static int nearestSymbol(int color) {
        float[] hsv = new float[3];
        Color.colorToHSV(color, hsv);
        int nearest = 0;
        float nearestDistance = Float.MAX_VALUE;
        for (int index = 0; index < TARGET_HUES.length; index++) {
            float direct = Math.abs(hsv[0] - TARGET_HUES[index]);
            float distance = Math.min(direct, 360.0f - direct);
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearest = index;
            }
        }
        return nearest;
    }

    private interface PixelSource {
        int colorAt(float x, float y);
    }

    private static final class BitmapPixels implements PixelSource {
        private final Bitmap bitmap;

        BitmapPixels(Bitmap bitmap) {
            this.bitmap = bitmap;
        }

        @Override
        public int colorAt(float x, float y) {
            int column = Math.max(0, Math.min(Math.round(x), bitmap.getWidth() - 1));
            int row = Math.max(0, Math.min(Math.round(y), bitmap.getHeight() - 1));
            return bitmap.getPixel(column, row);
        }
    }

    private static final class YuvPixels implements PixelSource {
        private final Image.Plane yPlane;
        private final Image.Plane uPlane;
        private final Image.Plane vPlane;
        private final ByteBuffer yBuffer;
        private final ByteBuffer uBuffer;
        private final ByteBuffer vBuffer;
        private final int width;
        private final int height;

        YuvPixels(Image image) {
            Image.Plane[] planes = image.getPlanes();
            yPlane = planes[0];
            uPlane = planes[1];
            vPlane = planes[2];
            yBuffer = yPlane.getBuffer().duplicate();
            uBuffer = uPlane.getBuffer().duplicate();
            vBuffer = vPlane.getBuffer().duplicate();
            width = image.getWidth();
            height = image.getHeight();
        }

        @Override
        public int colorAt(float x, float y) {
            int column = Math.max(0, Math.min(Math.round(x), width - 1));
            int row = Math.max(0, Math.min(Math.round(y), height - 1));
            int yValue = sample(yBuffer, yPlane, column, row);
            int uValue = sample(uBuffer, uPlane, column / 2, row / 2) - 128;
            int vValue = sample(vBuffer, vPlane, column / 2, row / 2) - 128;
            float luminance = Math.max(0, yValue - 16) * 1.164f;
            int red = clamp(Math.round(luminance + 1.596f * vValue));
            int green = clamp(Math.round(luminance - 0.392f * uValue - 0.813f * vValue));
            int blue = clamp(Math.round(luminance + 2.017f * uValue));
            return Color.rgb(red, green, blue);
        }

        private static int sample(ByteBuffer buffer, Image.Plane plane, int column, int row) {
            int index = buffer.position() + row * plane.getRowStride() + column * plane.getPixelStride();
            if (index < buffer.position() || index >= buffer.limit()) {
                return 128;
            }
            return buffer.get(index) & 0xFF;
        }

        private static int clamp(int value) {
            return Math.max(0, Math.min(value, 255));
        }
    }
}
