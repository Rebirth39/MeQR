package com.lucasli.meqr;

import android.graphics.Typeface;
import android.os.Build;

final class TagTextWeight {
    static final int REGULAR = 400;
    static final int SEMIBOLD = 600;
    static final int HEAVY = 900;

    private TagTextWeight() {}

    static int normalize(int weight) {
        return weight == SEMIBOLD || weight == HEAVY ? weight : REGULAR;
    }

    static int next(int weight) {
        return weight == REGULAR ? SEMIBOLD : weight == SEMIBOLD ? HEAVY : REGULAR;
    }

    static Typeface typeface(int weight) {
        int normalized = normalize(weight);
        if (Build.VERSION.SDK_INT >= 28) return Typeface.create(Typeface.DEFAULT, normalized, false);
        return Typeface.create(normalized == HEAVY ? "sans-serif-black"
                : normalized == SEMIBOLD ? "sans-serif-medium" : "sans-serif", Typeface.NORMAL);
    }

    static String labelKey(int weight) {
        return weight == HEAVY ? "tagWeightHeavy" : weight == SEMIBOLD ? "tagWeightSemibold" : "tagWeightRegular";
    }
}
