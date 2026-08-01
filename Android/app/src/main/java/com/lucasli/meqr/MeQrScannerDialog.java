package com.lucasli.meqr;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ImageFormat;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.Log;
import android.util.Size;
import android.view.Gravity;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.google.zxing.PlanarYUVLuminanceSource;
import com.google.zxing.Result;

import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Full-screen QR scanner dialog backed by Camera2 + ZXing frame decoding.
 * Works without adding any new dependency.
 */
final class MeQrScannerDialog extends android.app.Dialog {
    interface Listener {
        void onPayload(String payload);

        void onImportRequest();
    }

    private static final String TAG = "MeQrScannerDialog";

    private final I18n i18n;
    private final Listener listener;
    private final TextureView preview = new TextureView(getContext());
    private final AtomicBoolean analyzing = new AtomicBoolean(false);
    private final AtomicBoolean decodePending = new AtomicBoolean(false);

    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private ImageReader imageReader;
    private Size captureSize = new Size(1280, 720);
    private String lastPayload = "";
    private long lastPayloadAt;
    private boolean payloadDelivered;

    MeQrScannerDialog(Context context, I18n i18n, Listener listener) {
        super(context, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        this.i18n = i18n;
        this.listener = listener;
        buildUi();
    }

    private void buildUi() {
        FrameLayout root = new FrameLayout(getContext());
        root.setBackgroundColor(Color.BLACK);
        root.addView(preview, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        root.addView(new ScanOverlay(getContext()), new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        Button close = new Button(getContext());
        close.setText("×");
        close.setTextSize(26);
        close.setTextColor(Color.WHITE);
        close.setGravity(Gravity.CENTER);
        close.setBackground(Ui.rounded(Color.argb(90, 255, 255, 255), dp(24)));
        close.setOnClickListener(v -> dismiss());
        FrameLayout.LayoutParams closeParams = new FrameLayout.LayoutParams(dp(52), dp(52), Gravity.TOP | Gravity.END);
        closeParams.setMargins(0, dp(16), dp(16), 0);
        root.addView(close, closeParams);

        LinearLayout bottom = new LinearLayout(getContext());
        bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setGravity(Gravity.CENTER_HORIZONTAL);
        bottom.setPadding(dp(24), dp(18), dp(24), dp(28));

        TextView hint = new TextView(getContext());
        hint.setText(i18n.t("scanMeQrHint"));
        hint.setTextColor(Color.WHITE);
        hint.setTextSize(15);
        hint.setGravity(Gravity.CENTER);
        hint.setShadowLayer(6, 0, 2, Color.BLACK);
        bottom.addView(hint);

        Button importButton = new Button(getContext());
        importButton.setText(i18n.t("importFromPhoto"));
        importButton.setAllCaps(false);
        importButton.setTextSize(16);
        importButton.setTextColor(Color.WHITE);
        importButton.setGravity(Gravity.CENTER);
        importButton.setBackground(Ui.rounded(Color.argb(80, 255, 255, 255), dp(22)));
        importButton.setOnClickListener(v -> {
            dismiss();
            listener.onImportRequest();
        });
        LinearLayout.LayoutParams importParams = new LinearLayout.LayoutParams(dp(210), dp(48));
        importParams.setMargins(0, dp(14), 0, 0);
        bottom.addView(importButton, importParams);

        root.addView(bottom, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM));
        setContentView(root);
        Window window = getWindow();
        if (window != null) {
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        }
        setOnDismissListener(ignored -> closeCamera());
    }

    private void startCamera() {
        if (!preview.isAvailable()) {
            preview.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
                @Override
                public void onSurfaceTextureAvailable(android.graphics.SurfaceTexture surface, int width, int height) {
                    startCamera();
                }

                @Override
                public void onSurfaceTextureSizeChanged(android.graphics.SurfaceTexture surface, int width, int height) {
                }

                @Override
                public boolean onSurfaceTextureDestroyed(android.graphics.SurfaceTexture surface) {
                    return true;
                }

                @Override
                public void onSurfaceTextureUpdated(android.graphics.SurfaceTexture surface) {
                }
            });
            return;
        }

        cameraThread = new HandlerThread("meqr-scanner");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());

        CameraManager manager = (CameraManager) getContext().getSystemService(Context.CAMERA_SERVICE);
        try {
            String cameraId = null;
            CameraCharacteristics selectedCharacteristics = null;
            for (String id : manager.getCameraIdList()) {
                CameraCharacteristics characteristics = manager.getCameraCharacteristics(id);
                Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    cameraId = id;
                    selectedCharacteristics = characteristics;
                    break;
                }
            }
            if (cameraId == null) {
                listener.onPayload(null);
                dismiss();
                return;
            }
            captureSize = chooseCaptureSize(selectedCharacteristics);
            manager.openCamera(cameraId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(CameraDevice device) {
                    cameraDevice = device;
                    configureSession();
                }

                @Override
                public void onDisconnected(CameraDevice device) {
                    device.close();
                    cameraDevice = null;
                }

                @Override
                public void onError(CameraDevice device, int error) {
                    device.close();
                    cameraDevice = null;
                }
            }, cameraHandler);
        } catch (CameraAccessException | SecurityException exception) {
            Log.e(TAG, "Camera open failed", exception);
            dismiss();
        }
    }

    private void configureSession() {
        android.graphics.SurfaceTexture texture = preview.getSurfaceTexture();
        if (texture == null || cameraDevice == null) {
            return;
        }
        texture.setDefaultBufferSize(captureSize.getWidth(), captureSize.getHeight());
        android.view.Surface previewSurface = new android.view.Surface(texture);

        imageReader = ImageReader.newInstance(captureSize.getWidth(), captureSize.getHeight(), ImageFormat.YUV_420_888, 2);
        imageReader.setOnImageAvailableListener(imageAvailable -> analyzeFrame(imageReader.acquireLatestImage()), cameraHandler);

        try {
            final android.view.Surface readerSurface = imageReader.getSurface();
            cameraDevice.createCaptureSession(
                java.util.Arrays.asList(previewSurface, readerSurface),
                new CameraCaptureSession.StateCallback() {
                    @Override
                    public void onConfigured(CameraCaptureSession session) {
                        captureSession = session;
                        try {
                            CaptureRequest.Builder builder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
                            builder.addTarget(previewSurface);
                            builder.addTarget(readerSurface);
                            builder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
                            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
                            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
                            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO);
                            session.setRepeatingRequest(builder.build(), null, cameraHandler);
                        } catch (CameraAccessException exception) {
                            Log.e(TAG, "Preview start failed", exception);
                        }
                    }

                    @Override
                    public void onConfigureFailed(CameraCaptureSession session) {
                        Log.e(TAG, "Session configure failed");
                    }
                },
                cameraHandler
            );
        } catch (CameraAccessException exception) {
            Log.e(TAG, "Session create failed", exception);
        }
    }

    private Size chooseCaptureSize(CameraCharacteristics characteristics) {
        if (characteristics == null) {
            return new Size(1280, 720);
        }
        StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        if (map == null) {
            return new Size(1280, 720);
        }
        Size[] yuvSizes = map.getOutputSizes(ImageFormat.YUV_420_888);
        Size[] previewSizes = map.getOutputSizes(SurfaceTexture.class);
        if (yuvSizes == null || yuvSizes.length == 0) {
            return new Size(1280, 720);
        }

        Size best = null;
        double bestScore = Double.MAX_VALUE;
        for (Size size : yuvSizes) {
            if (!containsSize(previewSizes, size)) {
                continue;
            }
            long area = (long) size.getWidth() * size.getHeight();
            if (area < 640L * 480L || area > 1920L * 1080L) {
                continue;
            }
            double aspect = size.getWidth() / (double) size.getHeight();
            double aspectPenalty = Math.abs(aspect - (16.0 / 9.0)) * 1000.0;
            double areaPenalty = Math.abs(area - 1280.0 * 720.0) / 1000.0;
            double score = aspectPenalty + areaPenalty;
            if (score < bestScore) {
                best = size;
                bestScore = score;
            }
        }
        if (best != null) {
            return best;
        }
        for (Size size : yuvSizes) {
            if (containsSize(previewSizes, size)) {
                return size;
            }
        }
        return yuvSizes[0];
    }

    private boolean containsSize(Size[] sizes, Size target) {
        if (sizes == null) {
            return false;
        }
        for (Size size : sizes) {
            if (size.getWidth() == target.getWidth() && size.getHeight() == target.getHeight()) {
                return true;
            }
        }
        return false;
    }

    private void analyzeFrame(Image image) {
        if (image == null) {
            return;
        }
        if (!analyzing.compareAndSet(false, true)) {
            image.close();
            return;
        }
        if (payloadDelivered) {
            image.close();
            analyzing.set(false);
            return;
        }
        try {
            Image.Plane yPlane = image.getPlanes()[0];
            int width = image.getWidth();
            int height = image.getHeight();
            byte[] luminance = extractLuminance(yPlane, width, height);

            PlanarYUVLuminanceSource source = new PlanarYUVLuminanceSource(
                luminance, width, height, 0, 0, width, height, false
            );
            Result result = QrImageDecoder.decode(source);
            if (result != null && result.getText() != null && !result.getText().isEmpty()) {
                String payload = result.getText();
                long now = System.currentTimeMillis();
                if (!payload.equals(lastPayload) || now - lastPayloadAt > 2000) {
                    lastPayload = payload;
                    lastPayloadAt = now;
                    payloadDelivered = true;
                    vibrate();
                    new Handler(android.os.Looper.getMainLooper()).post(() -> {
                        closeCamera();
                        listener.onPayload(payload);
                        dismiss();
                    });
                }
            }
        } catch (Exception ignored) {
        } finally {
            image.close();
            analyzing.set(false);
        }
    }

    private byte[] extractLuminance(Image.Plane plane, int width, int height) {
        ByteBuffer buffer = plane.getBuffer().duplicate();
        int rowStride = plane.getRowStride();
        int pixelStride = plane.getPixelStride();
        int base = buffer.position();
        int limit = buffer.limit();
        byte[] luminance = new byte[width * height];
        Arrays.fill(luminance, (byte) 0xFF);

        for (int row = 0; row < height; row++) {
            int rowStart = base + row * rowStride;
            if (rowStart >= limit) {
                break;
            }
            int outputStart = row * width;
            if (pixelStride == 1) {
                int count = Math.min(width, limit - rowStart);
                buffer.position(rowStart);
                buffer.get(luminance, outputStart, count);
                continue;
            }
            for (int column = 0; column < width; column++) {
                int index = rowStart + column * pixelStride;
                if (index >= limit) {
                    break;
                }
                luminance[outputStart + column] = buffer.get(index);
            }
        }
        return luminance;
    }

    private void vibrate() {
        try {
            Vibrator vibrator = (Vibrator) getContext().getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                vibrator.vibrate(VibrationEffect.createOneShot(80, VibrationEffect.DEFAULT_AMPLITUDE));
            }
        } catch (Exception ignored) {
        }
    }

    private void closeCamera() {
        payloadDelivered = true;
        if (captureSession != null) {
            captureSession.close();
            captureSession = null;
        }
        if (cameraDevice != null) {
            cameraDevice.close();
            cameraDevice = null;
        }
        if (imageReader != null) {
            imageReader.close();
            imageReader = null;
        }
        if (cameraThread != null) {
            cameraThread.quitSafely();
            cameraThread = null;
        }
        cameraHandler = null;
    }

    @Override
    public void show() {
        super.show();
        preview.post(this::startCamera);
    }

    private int dp(int value) {
        return Math.round(value * getContext().getResources().getDisplayMetrics().density);
    }

    private static final class ScanOverlay extends View {
        private final Paint dimPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint framePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Rect frame = new Rect();
        private final int teal = Color.rgb(57, 197, 187);

        ScanOverlay(Context context) {
            super(context);
            dimPaint.setColor(Color.argb(120, 0, 0, 0));
            framePaint.setStyle(Paint.Style.STROKE);
            framePaint.setStrokeWidth(dp(4));
            framePaint.setColor(teal);
        }

        @Override
        protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            int size = Math.min(w - dp(64), h - dp(320));
            if (size <= 0) {
                size = Math.min(w, h) - dp(80);
            }
            int left = (w - size) / 2;
            int top = (h - size) / 2 - dp(20);
            frame.set(left, top, left + size, top + size);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            canvas.drawRect(0, 0, getWidth(), getHeight(), dimPaint);
            canvas.drawRect(frame, framePaint);
            int corner = dp(28);
            float stroke = dp(4);
            canvas.drawLine(frame.left, frame.top, frame.left + corner, frame.top, framePaint);
            canvas.drawLine(frame.left, frame.top, frame.left, frame.top + corner, framePaint);
            canvas.drawLine(frame.right - corner, frame.top, frame.right, frame.top, framePaint);
            canvas.drawLine(frame.right, frame.top, frame.right, frame.top + corner, framePaint);
            canvas.drawLine(frame.left, frame.bottom, frame.left + corner, frame.bottom, framePaint);
            canvas.drawLine(frame.left, frame.bottom, frame.left, frame.bottom - corner, framePaint);
            canvas.drawLine(frame.right - corner, frame.bottom, frame.right, frame.bottom, framePaint);
            canvas.drawLine(frame.right, frame.bottom, frame.right, frame.bottom - corner, framePaint);
        }

        private int dp(int value) {
            return Math.round(value * getResources().getDisplayMetrics().density);
        }
    }
}
