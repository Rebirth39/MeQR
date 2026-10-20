package com.lucasli.meqr;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.widget.TextView;

final class TagPairStyle {
    static void apply(TextView view, TagPair pair, String language) {
        String left = pair.left.display(language), right = pair.right.display(language);
        SpannableString label = new SpannableString(left + "&" + right);
        int[] colors = pair.colors();
        label.setSpan(new ForegroundColorSpan(pair.isCB() ? colors[0] : Color.WHITE), 0, left.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        label.setSpan(new ForegroundColorSpan(pair.isCB() ? Color.GRAY : Color.WHITE), left.length(), left.length() + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        label.setSpan(new ForegroundColorSpan(pair.isCB() ? colors[1] : Color.WHITE), left.length() + 1, label.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        view.setText(label);
        view.setTextColor(Color.WHITE);
        view.setShadowLayer(pair.isCB() ? 0 : view.getResources().getDisplayMetrics().density, 0, 0, 0x73000000);
        view.setContentDescription(pair.display(language) + " " + pair.kind);
    }

    static void draw(Canvas canvas, TagPair pair, String language, RectF bounds, Paint source, float density) {
        TagSegmentDrawable background = new TagSegmentDrawable(pair.colors(), bounds.height() / 2, pair.isCB() ? 2 * density : 0);
        int save = canvas.save();
        canvas.translate(bounds.left, bounds.top);
        background.setBounds(0, 0, Math.round(bounds.width()), Math.round(bounds.height()));
        background.draw(canvas);
        Paint paint = new Paint(source);
        paint.setStyle(Paint.Style.FILL);
        paint.setTextAlign(Paint.Align.LEFT);
        if (!pair.isCB()) paint.setShadowLayer(density, 0, 0, 0x73000000);
        String[] parts = {pair.left.display(language), "&", pair.right.display(language)};
        int[] colors = {pair.isCB() ? pair.left.color() : Color.WHITE, pair.isCB() ? Color.GRAY : Color.WHITE,
                pair.isCB() ? pair.right.color() : Color.WHITE};
        float width = paint.measureText(String.join("", parts));
        float scale = Math.min(1, Math.max(1, bounds.width() - 12 * density) / Math.max(1, width));
        canvas.translate((bounds.width() - width * scale) / 2, 0);
        canvas.scale(scale, 1);
        Paint.FontMetrics metrics = paint.getFontMetrics();
        float baseline = bounds.height() / 2 - (metrics.ascent + metrics.descent) / 2;
        float x = 0;
        for (int index = 0; index < parts.length; index++) {
            paint.setColor(colors[index]);
            canvas.drawText(parts[index], x, baseline, paint);
            x += paint.measureText(parts[index]);
        }
        canvas.restoreToCount(save);
    }
}
