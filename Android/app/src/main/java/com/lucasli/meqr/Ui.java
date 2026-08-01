package com.lucasli.meqr;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

/** Shared design tokens and view factories for the Android UI. */
final class Ui {
    // Brand palette (aligned with meqrcode.cn)
    static final int TEAL = Color.rgb(57, 197, 187);
    static final int TEAL_DEEP = Color.rgb(24, 55, 82);
    static final int BLUE = Color.rgb(51, 129, 176);
    static final int SKY = Color.rgb(161, 209, 234);

    // Surfaces (deep, calm dark theme)
    static final int BG = Color.rgb(13, 17, 23);
    static final int BG_TOP = Color.rgb(22, 38, 52);
    static final int SURFACE = Color.rgb(23, 29, 38);
    static final int SURFACE_2 = Color.rgb(31, 39, 50);
    static final int BORDER = Color.rgb(43, 54, 68);
    static final int TEXT = Color.rgb(242, 245, 249);
    static final int MUTED = Color.rgb(150, 162, 178);
    static final int DIM = Color.rgb(108, 120, 138);

    private Ui() {
    }

    static GradientDrawable rounded(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    static GradientDrawable rounded(int color, int radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = rounded(color, radius);
        drawable.setStroke(strokeWidth, strokeColor);
        return drawable;
    }

    static GradientDrawable gradient(int startColor, int endColor, int radius) {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{startColor, endColor}
        );
        drawable.setCornerRadius(radius);
        return drawable;
    }

    static GradientDrawable tealButton(int radius) {
        return gradient(TEAL, Color.rgb(44, 156, 148), radius);
    }

    static TextView text(Context context, String value, int color, float size) {
        TextView view = new TextView(context);
        view.setText(value);
        view.setTextColor(color);
        view.setTextSize(size);
        return view;
    }

    static TextView boldText(Context context, String value, int color, float size) {
        TextView view = text(context, value, color, size);
        view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    static Button button(Context context, String value) {
        Button button = new Button(context);
        button.setText(value);
        button.setAllCaps(false);
        button.setGravity(Gravity.CENTER);
        return button;
    }

    static EditText field(Context context, String hint, String value, boolean multiline) {
        EditText edit = new EditText(context);
        edit.setHint(hint);
        edit.setText(value);
        edit.setTextSize(17);
        edit.setTextColor(TEXT);
        edit.setHintTextColor(DIM);
        edit.setBackgroundColor(Color.TRANSPARENT);
        edit.setPadding(dp(context, 16), dp(context, 10), dp(context, 16), dp(context, 10));
        edit.setSingleLine(!multiline);
        edit.setMinLines(multiline ? 2 : 1);
        edit.setGravity(multiline ? Gravity.TOP : Gravity.CENTER_VERTICAL);
        edit.setInputType(
                multiline
                        ? android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE
                        : android.text.InputType.TYPE_CLASS_TEXT
        );
        return edit;
    }

    static int dp(Context context, int value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }
}
