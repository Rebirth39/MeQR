package com.lucasli.meqr;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;

final class TagSegmentDrawable extends Drawable {
    private final int[] colors;
    private final float radius;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    TagSegmentDrawable(int[] colors, float radius) { this.colors = colors.clone(); this.radius = radius; }
    @Override public void draw(Canvas canvas) {
        RectF bounds = new RectF(getBounds());
        Path clip = new Path();
        clip.addRoundRect(bounds, radius, radius, Path.Direction.CW);
        int save = canvas.save();
        canvas.clipPath(clip);
        for (int i = 0; i < colors.length; i++) {
            paint.setColor(colors[i]);
            canvas.drawRect(bounds.left + bounds.width() * i / colors.length, bounds.top,
                    bounds.left + bounds.width() * (i + 1) / colors.length, bounds.bottom, paint);
        }
        canvas.restoreToCount(save);
    }
    @Override public void setAlpha(int alpha) { paint.setAlpha(alpha); invalidateSelf(); }
    @Override public void setColorFilter(ColorFilter filter) { paint.setColorFilter(filter); invalidateSelf(); }
    @Override public int getOpacity() { return PixelFormat.TRANSLUCENT; }
}
