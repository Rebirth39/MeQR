package com.lucasli.meqr;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.text.StaticLayout;
import android.text.TextPaint;

import java.io.File;

final class CardRenderer {
    private CardRenderer() {
    }

    static Bitmap render(MeQrProfile profile, I18n i18n, int width) {
        int height = Math.round(width * 1.32f);
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        float density = width / 360f;
        float radius = profile.cornerRadius * density;
        RectF bounds = new RectF(0, 0, width, height);

        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(parseColor(profile.backgroundColor, Color.WHITE));
        canvas.drawColor(Color.TRANSPARENT);

        Path clip = new Path();
        clip.addRoundRect(bounds, radius, radius, Path.Direction.CW);
        canvas.save();
        canvas.clipPath(clip);
        canvas.drawRoundRect(bounds, radius, radius, paint);

        Bitmap background = decode(profile.backgroundPath);
        if (background != null) {
            drawCenterCrop(canvas, background, bounds, paint);
            if (profile.cardOpacity < 0.98f) {
                paint.setColor(applyAlpha(parseColor(profile.backgroundColor, Color.WHITE), 1f - profile.cardOpacity));
                canvas.drawRect(bounds, paint);
            }
        }

        int textColor = parseColor(profile.textColor, Color.rgb(17, 17, 17));
        float padding = 24f * density;
        float avatarSize = 86f * density;
        float top = 30f * density;

        Bitmap avatar = decode(profile.avatarPath);
        RectF avatarBounds = new RectF(padding, top, padding + avatarSize, top + avatarSize);
        if (avatar != null) {
            Path avatarClip = new Path();
            avatarClip.addOval(avatarBounds, Path.Direction.CW);
            canvas.save();
            canvas.clipPath(avatarClip);
            drawCenterCrop(canvas, avatar, avatarBounds, paint);
            canvas.restore();
        } else {
            paint.setColor(Color.argb(28, 0, 0, 0));
            canvas.drawOval(avatarBounds, paint);
            paint.setColor(textColor);
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setTextSize(34f * density);
            paint.setTypeface(Typeface.DEFAULT_BOLD);
            String initial = profile.name == null || profile.name.isEmpty() ? "M" : profile.name.substring(0, 1);
            Paint.FontMetrics fm = paint.getFontMetrics();
            canvas.drawText(initial, avatarBounds.centerX(), avatarBounds.centerY() - (fm.ascent + fm.descent) / 2, paint);
        }

        TextPaint titlePaint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        titlePaint.setColor(textColor);
        titlePaint.setTypeface(Typeface.DEFAULT_BOLD);
        titlePaint.setTextSize(25f * density);
        float textLeft = padding + avatarSize + 16f * density;
        drawText(canvas, profile.name == null || profile.name.trim().isEmpty() ? i18n.t("appName") : profile.name.trim(), titlePaint, textLeft, top + 8f * density, width - textLeft - padding, 2);

        TextPaint subPaint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        subPaint.setColor(adjustAlpha(textColor, 0.72f));
        subPaint.setTextSize(14.5f * density);
        drawText(canvas, profile.subtitle == null ? "" : profile.subtitle, subPaint, textLeft, top + 46f * density, width - textLeft - padding, 3);

        float qrSize = width - padding * 2f - 44f * density;
        Bitmap qr = QrCodeGenerator.generate(profile.qrContent, parseColor(profile.qrColor, Color.BLACK), Math.round(qrSize));
        float qrLeft = padding + 22f * density;
        float qrTop = 156f * density;
        paint.setColor(Color.WHITE);
        canvas.drawRoundRect(new RectF(qrLeft - 12f * density, qrTop - 12f * density, qrLeft + qrSize + 12f * density, qrTop + qrSize + 12f * density), 20f * density, 20f * density, paint);
        canvas.drawBitmap(qr, qrLeft, qrTop, paint);

        paint.setColor(adjustAlpha(textColor, 0.12f));
        RectF chip = new RectF(padding, height - 62f * density, width - padding, height - 24f * density);
        canvas.drawRoundRect(chip, 18f * density, 18f * density, paint);
        paint.setColor(textColor);
        paint.setTypeface(Typeface.DEFAULT_BOLD);
        paint.setTextSize(15f * density);
        paint.setTextAlign(Paint.Align.CENTER);
        Paint.FontMetrics fm = paint.getFontMetrics();
        canvas.drawText(profile.platformDisplayName(i18n), chip.centerX(), chip.centerY() - (fm.ascent + fm.descent) / 2, paint);

        canvas.restore();
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2.5f * density);
        paint.setColor(parseColor(profile.borderColor, Color.rgb(17, 17, 17)));
        canvas.drawRoundRect(insetCopy(bounds, paint.getStrokeWidth() / 2), radius, radius, paint);
        paint.setStyle(Paint.Style.FILL);
        return bitmap;
    }

    static int parseColor(String hex, int fallback) {
        try {
            return Color.parseColor(hex == null || hex.trim().isEmpty() ? "#000000" : hex.trim());
        } catch (IllegalArgumentException exception) {
            return fallback;
        }
    }

    private static Bitmap decode(String path) {
        if (path == null || path.isEmpty() || !new File(path).exists()) {
            return null;
        }
        return BitmapFactory.decodeFile(path);
    }

    private static void drawCenterCrop(Canvas canvas, Bitmap bitmap, RectF dst, Paint paint) {
        float scale = Math.max(dst.width() / bitmap.getWidth(), dst.height() / bitmap.getHeight());
        float srcWidth = dst.width() / scale;
        float srcHeight = dst.height() / scale;
        float left = (bitmap.getWidth() - srcWidth) / 2f;
        float top = (bitmap.getHeight() - srcHeight) / 2f;
        Rect src = new Rect(Math.round(left), Math.round(top), Math.round(left + srcWidth), Math.round(top + srcHeight));
        canvas.drawBitmap(bitmap, src, dst, paint);
    }

    private static void drawText(Canvas canvas, String text, TextPaint paint, float left, float top, float width, int maxLines) {
        if (text == null || text.trim().isEmpty()) {
            return;
        }
        StaticLayout layout = StaticLayout.Builder.obtain(text, 0, text.length(), paint, Math.round(width))
                .setMaxLines(maxLines)
                .setEllipsize(android.text.TextUtils.TruncateAt.END)
                .build();
        canvas.save();
        canvas.translate(left, top);
        layout.draw(canvas);
        canvas.restore();
    }

    private static int adjustAlpha(int color, float alpha) {
        return Color.argb(Math.round(Color.alpha(color) * alpha), Color.red(color), Color.green(color), Color.blue(color));
    }

    private static int applyAlpha(int color, float alpha) {
        return Color.argb(Math.round(255 * alpha), Color.red(color), Color.green(color), Color.blue(color));
    }

    private static RectF insetCopy(RectF rect, float inset) {
        return new RectF(rect.left + inset, rect.top + inset, rect.right - inset, rect.bottom - inset);
    }
}
