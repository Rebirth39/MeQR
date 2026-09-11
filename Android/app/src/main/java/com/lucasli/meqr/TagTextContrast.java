package com.lucasli.meqr;

import android.graphics.Color;
import android.graphics.Paint;
import android.widget.TextView;

final class TagTextContrast {
    final int foreground;
    final int outline;
    final boolean needsOutline;

    TagTextContrast(int[] colors) {
        double black = 21, white = 21;
        for (int color : colors) {
            double luminance = .2126 * linear(Color.red(color)) + .7152 * linear(Color.green(color)) + .0722 * linear(Color.blue(color));
            black = Math.min(black, (luminance + .05) / .05);
            white = Math.min(white, 1.05 / (luminance + .05));
        }
        foreground = white > black ? Color.WHITE : Color.BLACK;
        outline = foreground == Color.WHITE ? Color.BLACK : Color.WHITE;
        needsOutline = Math.max(black, white) < 4.5;
    }

    private static double linear(int value) {
        double c = value / 255.0;
        return c <= .04045 ? c / 12.92 : Math.pow((c + .055) / 1.055, 2.4);
    }

    void apply(TextView view) {
        view.setTextColor(foreground);
        view.setShadowLayer(needsOutline ? 1.2f * view.getResources().getDisplayMetrics().density : 0, 0, 0, outline);
    }

    void draw(android.graphics.Canvas canvas, String text, float x, float y, Paint paint, float density) {
        Paint.Style previous = paint.getStyle();
        float width = paint.getStrokeWidth();
        if (needsOutline) {
            paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(1.2f * density); paint.setColor(outline);
            canvas.drawText(text, x, y, paint);
        }
        paint.setStyle(Paint.Style.FILL); paint.setColor(foreground);
        canvas.drawText(text, x, y, paint);
        paint.setStyle(previous); paint.setStrokeWidth(width);
    }
}
