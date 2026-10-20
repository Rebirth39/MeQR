package com.lucasli.meqr;

import android.graphics.Typeface;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.TextUtils;

final class BioTextLayout {
    private BioTextLayout() {
    }

    static StaticLayout create(String text, int width, int height, float density, int color) {
        TextPaint paint = new TextPaint(TextPaint.ANTI_ALIAS_FLAG);
        paint.setTypeface(Typeface.DEFAULT);
        paint.setColor(color);
        for (int size = 15; size >= 12; size--) {
            paint.setTextSize(size * density);
            int capacity = Math.max(1, (int) (height / paint.getFontSpacing()));
            StaticLayout measured = builder(text, paint, width).setMaxLines(capacity + 1).build();
            if (measured.getHeight() <= height && measured.getLineEnd(measured.getLineCount() - 1) == text.length()) {
                return measured;
            }
            if (size == 12) {
                int lines = 0;
                while (lines < measured.getLineCount() && measured.getLineBottom(lines) <= height) {
                    lines++;
                }
                return builder(text, paint, width).setMaxLines(Math.max(1, lines))
                        .setEllipsize(TextUtils.TruncateAt.END).build();
            }
        }
        throw new IllegalStateException("Unable to lay out introduction");
    }

    private static StaticLayout.Builder builder(String text, TextPaint paint, int width) {
        return StaticLayout.Builder.obtain(text, 0, text.length(), paint, Math.max(1, width))
                .setIncludePad(false);
    }
}
