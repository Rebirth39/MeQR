package com.lucasli.meqr;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.widget.Button;
import android.widget.ImageView;

final class UiIcons {
    static int resource(String key) {
        switch (key) {
            case "+": return R.drawable.ic_add;
            case "✓": return R.drawable.ic_check;
            case "×": return android.R.drawable.ic_menu_close_clear_cancel;
            case "‹": case "←": return R.drawable.ic_chevron_left;
            case "›": case "→": return R.drawable.ic_chevron_right;
            case "▾": case "▼": return R.drawable.ic_expand_more;
            case "↑": return R.drawable.ic_arrow_up;
            case "↓": return R.drawable.ic_arrow_down;
            case "↗": return R.drawable.ic_open_in_new;
            case "share": return R.drawable.ic_ios_share;
            case "⋯": return R.drawable.ic_more;
            case "✎": return android.R.drawable.ic_menu_edit;
            case "⚙": return android.R.drawable.ic_menu_manage;
            case "文": return android.R.drawable.ic_menu_set_as;
            case "↻": return android.R.drawable.ic_popup_sync;
            case "i": return android.R.drawable.ic_menu_info_details;
            case "list": return android.R.drawable.ic_menu_agenda;
            case "QR": case "▦": return R.drawable.ic_qr_code;
            case "◎": case "◉": return android.R.drawable.ic_menu_myplaces;
            case "▤": return android.R.drawable.ic_menu_today;
            case "01": return android.R.drawable.ic_menu_help;
            default: return 0;
        }
    }

    static ImageView view(Context context, String key, int color) {
        ImageView image = new ImageView(context);
        image.setImageResource(resource(key));
        image.setColorFilter(color);
        image.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
        int padding = Math.round(7 * context.getResources().getDisplayMetrics().density);
        image.setPadding(padding, padding, padding, padding);
        image.setImportantForAccessibility(android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        return image;
    }

    // Existing factories can keep their Button API while drawing a centered native icon.
    static final class IconButton extends Button {
        private Drawable icon;
        IconButton(Context context) { super(context); }

        @Override public void setText(CharSequence text, BufferType type) {
            String key = text == null ? "" : text.toString();
            int resource = UiIcons.resource(key);
            icon = resource == 0 ? null : getContext().getDrawable(resource).mutate();
            super.setText(icon == null ? text : "", type);
            if (icon != null) {
                I18n language = new I18n(getContext());
                String label;
                switch (key) {
                    case "+": label = "add"; break;
                    case "×": label = "cancel"; break;
                    case "‹": case "←": label = "back"; break;
                    case "↑": label = "moveUp"; break;
                    case "↓": label = "moveDown"; break;
                    case "↗": label = "openLink"; break;
                    case "list": label = "cardList"; break;
                    case "文": label = "language"; break;
                    case "✓": label = "done"; break;
                    case "✎": label = "edit"; break;
                    case "QR": case "▦": label = "scanMeQr"; break;
                    case "›": case "→": label = "continue"; break;
                    default: label = "settings";
                }
                setContentDescription(language.t(label));
            }
            invalidate();
        }

        @Override protected void onDraw(Canvas canvas) {
            if (icon == null) { super.onDraw(canvas); return; }
            int side = Math.min(Math.min(getWidth(), getHeight()), Math.round(24 * getResources().getDisplayMetrics().density));
            int left = (getWidth() - side) / 2, top = (getHeight() - side) / 2;
            icon.setTint(getCurrentTextColor());
            icon.setAlpha(isEnabled() ? 255 : 100);
            icon.setBounds(left, top, left + side, top + side);
            icon.draw(canvas);
        }
    }
}
