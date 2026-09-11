package com.lucasli.meqr;

import android.content.Context;
import android.view.View;
import android.widget.LinearLayout;

/** Intrinsic-width tag chips with stable gaps and wrapping inside the form width. */
final class TagFlowLayout extends LinearLayout {
    private final int gap;
    TagFlowLayout(Context context) {
        super(context);
        gap = Math.round(6 * getResources().getDisplayMetrics().density);
    }
    @Override protected void onMeasure(int widthSpec, int heightSpec) {
        int width = MeasureSpec.getSize(widthSpec);
        int available = Math.max(0, width - getPaddingLeft() - getPaddingRight());
        int x = 0, y = 0, rowHeight = 0;
        for (int i = 0; i < getChildCount(); i++) {
            View child = getChildAt(i);
            if (child.getVisibility() == GONE) continue;
            child.measure(MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST),
                    getChildMeasureSpec(heightSpec, getPaddingTop() + getPaddingBottom(), child.getLayoutParams().height));
            if (x > 0 && x + child.getMeasuredWidth() > available) {
                x = 0; y += rowHeight + gap; rowHeight = 0;
            }
            x += child.getMeasuredWidth() + gap;
            rowHeight = Math.max(rowHeight, child.getMeasuredHeight());
        }
        setMeasuredDimension(width, resolveSize(y + rowHeight + getPaddingTop() + getPaddingBottom(), heightSpec));
    }
    @Override protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        int available = right - left - getPaddingLeft() - getPaddingRight();
        int x = 0, y = getPaddingTop(), rowHeight = 0;
        boolean rtl = getLayoutDirection() == LAYOUT_DIRECTION_RTL;
        for (int i = 0; i < getChildCount(); i++) {
            View child = getChildAt(i);
            if (child.getVisibility() == GONE) continue;
            int w = child.getMeasuredWidth(), h = child.getMeasuredHeight();
            if (x > 0 && x + w > available) { x = 0; y += rowHeight + gap; rowHeight = 0; }
            int childLeft = getPaddingLeft() + (rtl ? available - x - w : x);
            child.layout(childLeft, y, childLeft + w, y + h);
            x += w + gap;
            rowHeight = Math.max(rowHeight, h);
        }
    }
}
