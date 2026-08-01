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
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

final class CardRenderer {
    private CardRenderer() {
    }

    static Bitmap render(MeQrProfile profile, I18n i18n, int width) {
        return render(profile, i18n, width, 0);
    }

    static Bitmap render(MeQrProfile profile, I18n i18n, int width, int selectedIndex) {
        profile.syncLegacyFields();
        int index = Math.max(0, Math.min(selectedIndex, profile.qrItems.size() - 1));
        return "rhodes".equals(profile.template)
                ? renderRhodes(profile, i18n, width, index)
                : renderStandard(profile, i18n, width, index);
    }

    static Bitmap renderBack(MeQrProfile profile, I18n i18n, int width) {
        profile.syncLegacyFields();
        int height = Math.round(width * ("rhodes".equals(profile.template) ? 1.28f : 1.32f));
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        float density = width / 360f;
        float radius = ("rhodes".equals(profile.template) ? 14f : profile.cornerRadius) * density;
        RectF bounds = new RectF(0, 0, width, height);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        int textColor = parseColor(profile.textColor, Color.rgb(17, 17, 17));
        int backgroundColor = parseColor(profile.backgroundColor, Color.WHITE);
        int accentColor = parseColor(profile.qrColor, Color.BLACK);
        float padding = 22f * density;

        canvas.save();
        canvas.clipPath(roundedClip(bounds, radius));
        drawCardBackground(canvas, profile, bounds, paint);
        paint.setColor(applyAlpha(backgroundColor, profile.backgroundPath == null || profile.backgroundPath.isEmpty() ? 0.18f : 0.80f));
        canvas.drawRect(bounds, paint);

        if ("rhodes".equals(profile.template)) {
            float strip = 20f * density;
            paint.setColor(adjustAlpha(accentColor, 0.86f));
            canvas.drawRect(0, 0, width * 0.42f, strip, paint);
            paint.setColor(adjustAlpha(textColor, 0.86f));
            canvas.drawRect(width * 0.42f, 0, width * 0.78f, strip, paint);
            paint.setColor(adjustAlpha(backgroundColor, 0.94f));
            canvas.drawRect(width * 0.78f, 0, width, strip, paint);
        }

        float top = ("rhodes".equals(profile.template) ? 34f : 24f) * density;
        float avatarSize = 64f * density;
        RectF avatar = new RectF(padding, top, padding + avatarSize, top + avatarSize);
        drawAvatar(canvas, profile, avatar, textColor, paint, density);
        float textLeft = avatar.right + 14f * density;
        drawText(canvas, displayName(profile, i18n), textPaint(textColor, 23f * density, true), textLeft, top + 4f * density, width - textLeft - padding, 1);
        drawText(canvas, "MEQR · PROFILE", textPaint(adjustAlpha(textColor, 0.58f), 10f * density, true), textLeft, top + 39f * density, width - textLeft - padding, 1);

        TextPaint sectionPaint = textPaint(adjustAlpha(textColor, 0.62f), 11f * density, true);
        drawText(canvas, i18n.t("bio"), sectionPaint, padding, 112f * density, width - padding * 2f, 1);
        RectF introPanel = new RectF(padding, 134f * density, width - padding, 342f * density);
        paint.setColor(applyAlpha(backgroundColor, 0.72f));
        canvas.drawRoundRect(introPanel, 15f * density, 15f * density, paint);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(1f * density);
        paint.setColor(adjustAlpha(textColor, 0.14f));
        canvas.drawRoundRect(introPanel, 15f * density, 15f * density, paint);
        paint.setStyle(Paint.Style.FILL);
        String intro = profile.subtitle == null || profile.subtitle.trim().isEmpty() ? i18n.t("bioEmpty") : profile.subtitle.trim();
        drawText(canvas, intro, textPaint(adjustAlpha(textColor, 0.88f), 15f * density, false), introPanel.left + 14f * density, introPanel.top + 14f * density, introPanel.width() - 28f * density, 10);

        drawTagChips(canvas, profile, padding, 360f * density, width - padding * 2f, textColor, paint, density);
        drawPlatformChips(canvas, profile, i18n, -1, padding, 414f * density, width - padding * 2f, textColor, paint, density);
        canvas.restore();
        drawBorder(canvas, bounds, radius, profile.borderColor, density, paint);
        return bitmap;
    }

    private static Bitmap renderStandard(MeQrProfile profile, I18n i18n, int width, int index) {
        int height = Math.round(width * 1.32f);
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        float density = width / 360f;
        RectF bounds = new RectF(0, 0, width, height);
        float radius = profile.cornerRadius * density;
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        Path clip = roundedClip(bounds, radius);
        canvas.save();
        canvas.clipPath(clip);
        drawCardBackground(canvas, profile, bounds, paint);

        int textColor = parseColor(profile.textColor, Color.rgb(17, 17, 17));
        float padding = 22f * density;
        float avatarSize = 72f * density;
        float top = 24f * density;
        drawAvatar(canvas, profile, new RectF(padding, top, padding + avatarSize, top + avatarSize), textColor, paint, density);

        TextPaint title = textPaint(textColor, 24f * density, true);
        TextPaint subtitle = textPaint(adjustAlpha(textColor, 0.70f), 13f * density, false);
        float textLeft = padding + avatarSize + 14f * density;
        drawText(canvas, displayName(profile, i18n), title, textLeft, top + 3f * density, width - textLeft - padding, 1);
        drawText(canvas, profile.subtitle, subtitle, textLeft, top + 37f * density, width - textLeft - padding, 2);

        MeQrItem item = profile.qrItems.get(index);
        float qrSize = 240f * density;
        float qrLeft = (width - qrSize) / 2f;
        float qrTop = 122f * density;
        drawQr(canvas, item.qrContent, profile.qrColor, qrLeft, qrTop, qrSize, paint, density);

        float chipTop = 378f * density;
        drawPlatformChips(canvas, profile, i18n, index, padding, chipTop, width - padding * 2f, textColor, paint, density);
        drawTagChips(canvas, profile, padding, 422f * density, width - padding * 2f, textColor, paint, density);
        canvas.restore();
        drawBorder(canvas, bounds, radius, profile.borderColor, density, paint);
        return bitmap;
    }

    private static Bitmap renderRhodes(MeQrProfile profile, I18n i18n, int width, int index) {
        int height = Math.round(width * 1.28f);
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        float density = width / 360f;
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        RectF bounds = new RectF(0, 0, width, height);
        float radius = 14f * density;
        canvas.save();
        canvas.clipPath(roundedClip(bounds, radius));
        paint.setColor(applyAlpha(Color.WHITE, Math.max(0.72f, profile.cardOpacity)));
        canvas.drawRect(bounds, paint);

        int textColor = parseColor(profile.textColor, Color.rgb(17, 17, 17));
        int qrColor = parseColor(profile.qrColor, Color.BLACK);
        int background = parseColor(profile.backgroundColor, Color.WHITE);
        float strip = 24f * density;
        float third = width / 3f;
        paint.setColor(adjustAlpha(qrColor, 0.82f));
        canvas.drawRect(0, 0, third, strip, paint);
        paint.setColor(adjustAlpha(textColor, 0.82f));
        canvas.drawRect(third, 0, third * 2, strip, paint);
        paint.setColor(adjustAlpha(background, 0.92f));
        canvas.drawRect(third * 2, 0, width, strip, paint);

        float railWidth = 50f * density;
        paint.setColor(adjustAlpha(textColor, 0.88f));
        canvas.drawRect(0, strip, railWidth, height, paint);
        paint.setColor(Color.WHITE);
        paint.setTypeface(Typeface.DEFAULT_BOLD);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setTextSize(17f * density);
        canvas.save();
        canvas.rotate(-90, railWidth / 2f, 78f * density);
        canvas.drawText("MEQR", railWidth / 2f, 83f * density, paint);
        canvas.restore();
        drawBarcode(canvas, railWidth / 2f, 146f * density, paint, density);
        paint.setTextSize(14f * density);
        String date = new SimpleDateFormat("MM\ndd", Locale.US).format(new Date());
        String[] parts = date.split("\n");
        canvas.drawText(parts[0], railWidth / 2f, 276f * density, paint);
        canvas.drawText(parts[1], railWidth / 2f, 294f * density, paint);

        float contentLeft = railWidth + 12f * density;
        float contentRight = width - 12f * density;
        RectF hero = new RectF(contentLeft, strip + 12f * density, contentRight, strip + 148f * density);
        String bannerPath = profile.bannerPath == null || profile.bannerPath.trim().isEmpty()
                ? profile.backgroundPath
                : profile.bannerPath;
        Bitmap backgroundBitmap = decode(bannerPath);
        if (backgroundBitmap != null) {
            canvas.save();
            canvas.clipPath(roundedClip(hero, 8f * density));
            drawCenterCrop(canvas, backgroundBitmap, hero, paint);
            paint.setColor(Color.argb(110, 0, 0, 0));
            canvas.drawRect(hero.left, hero.centerY(), hero.right, hero.bottom, paint);
            canvas.restore();
        } else {
            paint.setColor(background);
            canvas.drawRoundRect(hero, 8f * density, 8f * density, paint);
            paint.setColor(adjustAlpha(qrColor, 0.18f));
            canvas.drawCircle(hero.right - 35f * density, hero.top + 32f * density, 70f * density, paint);
        }
        RectF avatar = new RectF(contentLeft + 10f * density, hero.bottom - 58f * density, contentLeft + 56f * density, hero.bottom - 12f * density);
        drawAvatar(canvas, profile, avatar, Color.WHITE, paint, density);
        TextPaint title = textPaint(Color.WHITE, 20f * density, true);
        drawText(canvas, displayName(profile, i18n), title, avatar.right + 9f * density, hero.bottom - 51f * density, contentRight - avatar.right - 15f * density, 1);
        TextPaint pass = textPaint(Color.argb(210, 255, 255, 255), 9.5f * density, true);
        drawText(canvas, "RHODES ISLAND PASS", pass, avatar.right + 9f * density, hero.bottom - 25f * density, contentRight - avatar.right - 15f * density, 1);

        MeQrItem item = profile.qrItems.get(index);
        float qrTop = hero.bottom + 14f * density;
        float qrSize = 164f * density;
        drawQr(canvas, item.qrContent, profile.qrColor, contentLeft + 8f * density, qrTop + 8f * density, qrSize - 16f * density, paint, density);
        float infoLeft = contentLeft + qrSize + 10f * density;
        TextPaint label = textPaint(adjustAlpha(textColor, 0.65f), 11f * density, true);
        drawText(canvas, "PLATFORM", label, infoLeft, qrTop + 4f * density, contentRight - infoLeft, 1);
        drawPlatformList(canvas, profile, i18n, index, infoLeft, qrTop + 28f * density, contentRight - infoLeft, textColor, paint, density);
        drawTagChips(canvas, profile, contentLeft, qrTop + qrSize + 16f * density, contentRight - contentLeft, textColor, paint, density);
        canvas.restore();
        drawBorder(canvas, bounds, radius, profile.borderColor, density, paint);
        return bitmap;
    }

    private static void drawCardBackground(Canvas canvas, MeQrProfile profile, RectF bounds, Paint paint) {
        paint.setColor(parseColor(profile.backgroundColor, Color.WHITE));
        canvas.drawRect(bounds, paint);
        Bitmap background = decode(profile.backgroundPath);
        if (background != null) {
            drawCenterCrop(canvas, background, bounds, paint);
            paint.setColor(applyAlpha(parseColor(profile.backgroundColor, Color.WHITE), 1f - profile.cardOpacity));
            canvas.drawRect(bounds, paint);
        }
    }

    private static void drawQr(Canvas canvas, String content, String color, float left, float top, float size, Paint paint, float density) {
        paint.setColor(Color.WHITE);
        canvas.drawRoundRect(new RectF(left - 9f * density, top - 9f * density, left + size + 9f * density, top + size + 9f * density), 14f * density, 14f * density, paint);
        Bitmap qr = QrCodeGenerator.generate(content, parseColor(color, Color.BLACK), Math.round(size));
        canvas.drawBitmap(qr, left, top, paint);
    }

    private static void drawPlatformChips(Canvas canvas, MeQrProfile profile, I18n i18n, int selected, float left, float top, float maxWidth, int textColor, Paint paint, float density) {
        float x = left;
        float y = top;
        for (int i = 0; i < profile.qrItems.size(); i++) {
            String label = profile.qrItems.get(i).platformDisplayName(i18n);
            paint.setTextSize(11f * density);
            paint.setTypeface(Typeface.DEFAULT_BOLD);
            float width = Math.min(maxWidth, paint.measureText(label) + 22f * density);
            if (x + width > left + maxWidth) {
                x = left;
                y += 30f * density;
            }
            paint.setColor(i == selected ? parseColor(profile.qrColor, Color.BLACK) : adjustAlpha(textColor, 0.12f));
            canvas.drawRoundRect(new RectF(x, y, x + width, y + 24f * density), 12f * density, 12f * density, paint);
            paint.setColor(i == selected ? contrastColor(parseColor(profile.qrColor, Color.BLACK)) : textColor);
            paint.setTextAlign(Paint.Align.CENTER);
            Paint.FontMetrics metrics = paint.getFontMetrics();
            canvas.drawText(label, x + width / 2f, y + 12f * density - (metrics.ascent + metrics.descent) / 2f, paint);
            x += width + 7f * density;
        }
        paint.setTextAlign(Paint.Align.LEFT);
    }

    private static void drawPlatformList(Canvas canvas, MeQrProfile profile, I18n i18n, int selected, float left, float top, float width, int textColor, Paint paint, float density) {
        for (int i = 0; i < profile.qrItems.size() && i < 5; i++) {
            float y = top + i * 27f * density;
            paint.setColor(i == selected ? parseColor(profile.qrColor, Color.BLACK) : adjustAlpha(textColor, 0.10f));
            canvas.drawRoundRect(new RectF(left, y, left + width, y + 22f * density), 11f * density, 11f * density, paint);
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setTypeface(Typeface.DEFAULT_BOLD);
            paint.setTextSize(9.5f * density);
            paint.setColor(i == selected ? contrastColor(parseColor(profile.qrColor, Color.BLACK)) : textColor);
            Paint.FontMetrics metrics = paint.getFontMetrics();
            canvas.drawText(profile.qrItems.get(i).platformDisplayName(i18n), left + width / 2f, y + 11f * density - (metrics.ascent + metrics.descent) / 2f, paint);
        }
        paint.setTextAlign(Paint.Align.LEFT);
    }

    private static void drawTagChips(Canvas canvas, MeQrProfile profile, float left, float top, float maxWidth, int textColor, Paint paint, float density) {
        float x = left;
        float y = top;
        for (int i = 0; i < profile.tags.size(); i++) {
            String tag = profile.tags.get(i);
            paint.setTextSize(10f * density);
            paint.setTypeface(Typeface.DEFAULT_BOLD);
            float width = Math.min(maxWidth, paint.measureText(tag) + 20f * density);
            if (x + width > left + maxWidth) {
                x = left;
                y += 27f * density;
            }
            String override = profile.tagColorOverrides.get(tag);
            int[] colors = CardTagColorPalette.colorsFor(tag, override);
            RectF chipBounds = new RectF(x, y, x + width, y + 21f * density);
            Path chipPath = new Path();
            chipPath.addRoundRect(chipBounds, 11f * density, 11f * density, Path.Direction.CW);
            canvas.save();
            canvas.clipPath(chipPath);
            float segmentWidth = width / colors.length;
            for (int colorIndex = 0; colorIndex < colors.length; colorIndex++) {
                paint.setColor(adjustAlpha(colors[colorIndex], 0.90f));
                float segmentLeft = x + colorIndex * segmentWidth;
                canvas.drawRect(segmentLeft, y, segmentLeft + segmentWidth + 1f, y + 21f * density, paint);
            }
            canvas.restore();
            paint.setColor(contrastColor(colors[0]));
            paint.setTextAlign(Paint.Align.CENTER);
            Paint.FontMetrics metrics = paint.getFontMetrics();
            canvas.drawText(tag, x + width / 2f, y + 10.5f * density - (metrics.ascent + metrics.descent) / 2f, paint);
            x += width + 6f * density;
        }
        paint.setTextAlign(Paint.Align.LEFT);
    }

    private static void drawAvatar(Canvas canvas, MeQrProfile profile, RectF bounds, int textColor, Paint paint, float density) {
        Bitmap avatar = decode(profile.avatarPath);
        Path clip = new Path();
        clip.addOval(bounds, Path.Direction.CW);
        canvas.save();
        canvas.clipPath(clip);
        if (avatar != null) {
            drawCenterCrop(canvas, avatar, bounds, paint);
        } else {
            paint.setColor(adjustAlpha(textColor, 0.14f));
            canvas.drawOval(bounds, paint);
            paint.setColor(textColor);
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setTypeface(Typeface.DEFAULT_BOLD);
            paint.setTextSize(28f * density);
            String name = profile.name == null ? "" : profile.name.trim();
            String initial = name.isEmpty() ? "M" : name.substring(0, 1);
            Paint.FontMetrics metrics = paint.getFontMetrics();
            canvas.drawText(initial, bounds.centerX(), bounds.centerY() - (metrics.ascent + metrics.descent) / 2f, paint);
        }
        canvas.restore();
        paint.setTextAlign(Paint.Align.LEFT);
    }

    private static void drawBarcode(Canvas canvas, float center, float top, Paint paint, float density) {
        float x = center - 17f * density;
        for (int i = 0; i < 12; i++) {
            float width = (i % 4 == 0 ? 3f : 1.5f) * density;
            paint.setColor(Color.argb(i % 3 == 0 ? 235 : 165, 255, 255, 255));
            canvas.drawRect(x, top, x + width, top + 92f * density, paint);
            x += width + 1.5f * density;
        }
    }

    private static String displayName(MeQrProfile profile, I18n i18n) {
        return profile.name == null || profile.name.trim().isEmpty() ? i18n.t("appName") : profile.name.trim();
    }

    static int parseColor(String hex, int fallback) {
        try {
            return Color.parseColor(hex == null || hex.trim().isEmpty() ? "#000000" : hex.trim());
        } catch (IllegalArgumentException exception) {
            return fallback;
        }
    }

    private static Bitmap decode(String path) {
        return path == null || path.isEmpty() || !new File(path).exists() ? null : BitmapFactory.decodeFile(path);
    }

    private static void drawCenterCrop(Canvas canvas, Bitmap bitmap, RectF destination, Paint paint) {
        float scale = Math.max(destination.width() / bitmap.getWidth(), destination.height() / bitmap.getHeight());
        float sourceWidth = destination.width() / scale;
        float sourceHeight = destination.height() / scale;
        float left = (bitmap.getWidth() - sourceWidth) / 2f;
        float top = (bitmap.getHeight() - sourceHeight) / 2f;
        Rect source = new Rect(Math.round(left), Math.round(top), Math.round(left + sourceWidth), Math.round(top + sourceHeight));
        canvas.drawBitmap(bitmap, source, destination, paint);
    }

    private static TextPaint textPaint(int color, float size, boolean bold) {
        TextPaint paint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(color);
        paint.setTextSize(size);
        paint.setTypeface(bold ? Typeface.DEFAULT_BOLD : Typeface.DEFAULT);
        return paint;
    }

    private static void drawText(Canvas canvas, String text, TextPaint paint, float left, float top, float width, int maxLines) {
        if (text == null || text.trim().isEmpty() || width <= 0) {
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

    private static Path roundedClip(RectF bounds, float radius) {
        Path path = new Path();
        path.addRoundRect(bounds, radius, radius, Path.Direction.CW);
        return path;
    }

    private static void drawBorder(Canvas canvas, RectF bounds, float radius, String color, float density, Paint paint) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2f * density);
        paint.setColor(parseColor(color, Color.BLACK));
        float inset = paint.getStrokeWidth() / 2f;
        canvas.drawRoundRect(new RectF(inset, inset, bounds.right - inset, bounds.bottom - inset), radius, radius, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private static int adjustAlpha(int color, float alpha) {
        return Color.argb(Math.round(Color.alpha(color) * alpha), Color.red(color), Color.green(color), Color.blue(color));
    }

    private static int applyAlpha(int color, float alpha) {
        return Color.argb(Math.round(255 * Math.max(0f, Math.min(1f, alpha))), Color.red(color), Color.green(color), Color.blue(color));
    }

    private static int contrastColor(int color) {
        double luminance = (0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)) / 255.0;
        return luminance > 0.58 ? Color.BLACK : Color.WHITE;
    }
}
