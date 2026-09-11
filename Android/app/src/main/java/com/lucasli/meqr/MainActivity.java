package com.lucasli.meqr;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.ImageButton;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.view.DragEvent;
import android.content.ClipData;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.google.zxing.Result;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class MainActivity extends Activity {
    private static final int TAG_CATEGORY_PAGE_SIZE = 24;
    private static final int PICK_AVATAR = 1001;
    private static final int PICK_BACKGROUND = 1002;
    private static final int PICK_QR_IMAGE = 1003;
    private static final int PICK_SCAN_QR = 1004;
    private static final int PICK_BANNER = 1005;
    private static final int PICK_EXPORT_BACKUP = 1006;
    private static final int PICK_IMPORT_BACKUP = 1007;
    private static final int REQUEST_WRITE_PHOTOS = 2001;
    private static final int REQUEST_CAMERA = 2002;
    private static final int COLOR_BG = Ui.BG;
    private static final int COLOR_PANEL = Ui.SURFACE_2;
    private static final int COLOR_PANEL_2 = Ui.SURFACE_2;
    private static final int COLOR_SURFACE = Ui.SURFACE;
    private static final int COLOR_TEXT = Ui.TEXT;
    private static final int COLOR_MUTED = Ui.MUTED;
    private static final int COLOR_SEPARATOR = Ui.BORDER;
    private static final int COLOR_BLUE = Ui.TEAL;
    private static final String ONBOARDING_VERSION = "android_profile_v1";

    private ProfileStore store;
    private BackupManager backupManager;
    private I18n i18n;
    private EncounterStore encounterStore;
    private EventStore eventStore;
    private AppUpdateManager updateManager;
    private AnnouncementManager announcementManager;
    private final List<MeQrProfile> profiles = new ArrayList<>();
    private LinearLayout list;
    private int currentPage = 0;
    private MeQrProfile editingProfile;
    private EditSession editSession;
    private Bitmap pendingMeQrBitmap;
    private MeQrItem pendingQrItem;
    private EditText pendingQrField;
    private boolean scanningPhoto;
    private boolean choosingScanImage;
    private boolean croppingBanner;

    private static final Pattern XHS_USER_ID = Pattern.compile("[0-9a-f]{24}");
    private final java.util.Map<String, String> xiaohongshuUserIDCache = new java.util.HashMap<>();
    private String lastRoutedPayload = "";
    private long lastRoutedAt;
    private boolean showingCardList;
    private int onboardingStep;

    private void handleMainBack() {
        if (!profiles.isEmpty() && !showingCardList) {
            showingCardList = true;
            renderMain();
        } else {
            moveTaskToBack(true);
        }
    }

    @Override public void onBackPressed() { handleMainBack(); }

    static void handleDialogBack(Dialog dialog, Runnable action) {
        dialog.setCancelable(false);
        dialog.setOnKeyListener((d, key, event) -> {
            if (key != android.view.KeyEvent.KEYCODE_BACK) return false;
            if (event.getAction() == android.view.KeyEvent.ACTION_UP) action.run();
            return true;
        });
        if (Build.VERSION.SDK_INT >= 33) {
            dialog.getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, action::run);
        }
    }

    private void confirmDiscard(Runnable discard) {
        new AlertDialog.Builder(this).setMessage(i18n.t("discardDraft"))
                .setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("discardChanges"), (d, which) -> discard.run()).show();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, this::handleMainBack);
        }
        getWindow().setStatusBarColor(COLOR_BG);
        getWindow().setNavigationBarColor(COLOR_BG);
        i18n = new I18n(this);
        store = new ProfileStore(this);
        backupManager = new BackupManager(this);
        encounterStore = new EncounterStore(this);
        eventStore = new EventStore(this);
        updateManager = new AppUpdateManager(this, i18n);
        announcementManager = new AnnouncementManager(this);
        eventStore.refreshRemoteEvents();
        RemoteTagCatalog.refresh(this, false, () -> {
            for (MeQrProfile profile : profiles) profile.reconcileTags(i18n.resolvedLanguage());
            try { store.save(profiles); } catch (Exception error) { Toast.makeText(this, i18n.t("saveFailed"), Toast.LENGTH_LONG).show(); }
            if (editSession == null && !isFinishing()) renderMain();
        });
        profiles.clear();
        profiles.addAll(store.load());
        renderMain();
        announcementManager.refresh();
        getWindow().getDecorView().postDelayed(updateManager::checkAutomatically, 1600);
        if (profiles.isEmpty() && !getSharedPreferences("settings", MODE_PRIVATE).getBoolean(ONBOARDING_VERSION, false)) {
            getWindow().getDecorView().post(this::showOnboarding);
        }
    }

    void renderAnnouncement(AnnouncementManager manager) { renderMain(); }

    @Override
    protected void onResume() {
        super.onResume();
        try { TagReportOutbox.get(this).kick(); }
        catch (Exception error) { Toast.makeText(this, new I18n(this).t("tagQueueSaveFailed"), Toast.LENGTH_LONG).show(); }
        if (updateManager != null) {
            updateManager.onResume();
        }
    }

    void renderMain() {
        for (MeQrProfile profile : profiles) profile.reconcileTags(i18n.resolvedLanguage());
        boolean immersive = !profiles.isEmpty() && !showingCardList;
        if (currentPage >= profiles.size()) {
            currentPage = Math.max(0, profiles.size() - 1);
        }
        if (currentPage < 0) {
            currentPage = 0;
        }
        FrameLayout shell = new FrameLayout(this);
        if (immersive) {
            shell.setBackgroundColor(Color.WHITE);
        } else {
            shell.setBackground(Ui.gradient(Ui.BG_TOP, Ui.BG, 0));
        }
        if (immersive) {
            getWindow().setStatusBarColor(Color.TRANSPARENT);
            getWindow().setNavigationBarColor(Color.TRANSPARENT);
            if (Build.VERSION.SDK_INT >= 23) {
                getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
            }
            addPageBackground(shell, profiles.get(currentPage));
        } else {
            getWindow().setStatusBarColor(COLOR_BG);
            getWindow().setNavigationBarColor(COLOR_BG);
            getWindow().getDecorView().setSystemUiVisibility(0);
        }

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.TRANSPARENT);

        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        toolbar.setPadding(dp(20), statusTop() + dp(12), dp(16), dp(10));
        toolbar.setOrientation(LinearLayout.HORIZONTAL);

        LinearLayout titleBlock = new LinearLayout(this);
        titleBlock.setOrientation(LinearLayout.VERTICAL);

        TextView title = new TextView(this);
        title.setText(i18n.t("appName"));
        title.setTextSize(24);
        title.setTextColor(immersive ? Color.BLACK : COLOR_TEXT);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        titleBlock.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText(profiles.isEmpty()
                ? i18n.t("emptyTitle")
                : (profiles.size() > 1
                        ? cardTitle(profiles.get(currentPage)) + "  ·  " + (currentPage + 1) + "/" + profiles.size()
                        : cardTitle(profiles.get(currentPage))));
        subtitle.setSingleLine(true);
        if (!immersive && !profiles.isEmpty()) subtitle.setText(i18n.t("cardList") + " · " + profiles.size());
        subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
        subtitle.setTextSize(13);
        subtitle.setTextColor(immersive ? Color.argb(190, 0, 0, 0) : COLOR_MUTED);
        titleBlock.addView(subtitle);
        MeQrProfile current = profiles.isEmpty() ? null : profiles.get(currentPage);
        Button menu = immersive ? lightIconButton("⋯") : iconButton("⋯");
        menu.setContentDescription(i18n.t("settings"));
        menu.setTooltipText(i18n.t("settings"));
        menu.setOnClickListener(v -> {
            if (current == null) showSettings();
            else showCardMenu(current, currentPage);
        });
        toolbar.addView(menu, new LinearLayout.LayoutParams(dp(48), dp(48)));
        toolbar.addView(new View(this), new LinearLayout.LayoutParams(0, 1, 1));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        actions.setPadding(dp(4), 0, dp(4), 0);
        actions.setBackground(rounded(immersive ? Color.argb(235, 238, 244, 246) : COLOR_PANEL,
                dp(26), immersive ? Color.argb(45, 70, 90, 100) : COLOR_SEPARATOR, dp(1)));
        actions.setContentDescription(i18n.t("mainActions"));
        addMainToolbarAction(actions, "▦", i18n.t("scanMeQr"), immersive, this::showScan);
        if (current != null) {
            addMainToolbarAction(actions, "share", i18n.t("meqrProfileCode"), immersive, () -> showShareMenu(current));
        }
        addMainToolbarAction(actions, "+", i18n.t("newProfile"), immersive, () -> showEditor(null));
        toolbar.addView(actions, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(52)));
        root.addView(toolbar);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        titleParams.setMargins(dp(20), 0, dp(20), dp(10));
        root.addView(titleBlock, titleParams);

        if (announcementManager != null && announcementManager.summary().length() > 0) {
            TextView notice = new TextView(this);
            notice.setText(announcementManager.summary());
            android.graphics.drawable.Drawable noticeArrow = getDrawable(R.drawable.ic_chevron_right).mutate();
            noticeArrow.setTint(COLOR_MUTED);
            noticeArrow.setBounds(0, 0, dp(24), dp(24));
            notice.setCompoundDrawablesRelative(null, null, noticeArrow, null);
            notice.setTextColor(COLOR_TEXT);
            notice.setTextSize(13);
            notice.setPadding(dp(16), dp(10), dp(16), dp(10));
            notice.setBackground(Ui.rounded(COLOR_PANEL, dp(12)));
            notice.setOnClickListener(v -> announcementManager.open());
            LinearLayout.LayoutParams noticeParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            noticeParams.setMargins(dp(16), 0, dp(16), dp(8));
            root.addView(notice, noticeParams);
        }

        if (immersive) {
            root.addView(pageView(profiles.get(currentPage), currentPage),
                    new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        } else {
            ScrollView scroll = new ScrollView(this);
            scroll.setFillViewport(true);
            list = new LinearLayout(this);
            list.setOrientation(LinearLayout.VERTICAL);
            list.setPadding(dp(16), dp(8), dp(16), dp(108));
            scroll.addView(list);
            root.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
            if (profiles.isEmpty()) renderEmptyState();
            else {
                for (int index = 0; index < profiles.size(); index++) {
                    final int selected = index;
                    Button cardRow = actionButton(cardTitle(profiles.get(index)));
                    cardRow.setTextColor(COLOR_TEXT);
                    cardRow.setBackground(rounded(COLOR_PANEL_2, dp(8)));
                    cardRow.setSingleLine(true);
                    cardRow.setEllipsize(android.text.TextUtils.TruncateAt.END);
                    cardRow.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
                    cardRow.setPadding(dp(16), 0, dp(16), 0);
                    android.graphics.drawable.Drawable chevron = getDrawable(R.drawable.ic_chevron_right).mutate();
                    chevron.setTint(COLOR_MUTED);
                    chevron.setBounds(0, 0, dp(24), dp(24));
                    cardRow.setCompoundDrawablesRelative(null, null, chevron, null);
                    cardRow.setOnClickListener(v -> { currentPage = selected; showingCardList = false; renderMain(); });
                    LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56));
                    rowParams.bottomMargin = dp(8);
                    list.addView(cardRow, rowParams);
                }
            }
        }

        shell.addView(root, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        setContentView(shell);
    }

    private void addMainToolbarAction(LinearLayout toolbar, String icon, String label,
                                      boolean light, Runnable action) {
        Button button = light ? lightIconButton(icon) : iconButton(icon);
        android.util.TypedValue feedback = new android.util.TypedValue();
        getTheme().resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, feedback, true);
        button.setBackgroundResource(feedback.resourceId);
        button.setContentDescription(label);
        button.setTooltipText(label);
        button.setOnClickListener(v -> action.run());
        toolbar.addView(button, new LinearLayout.LayoutParams(dp(48), dp(48)));
    }

    private String cardTitle(MeQrProfile profile) {
        return profile.name == null || profile.name.trim().isEmpty() ? i18n.t("appName") : profile.name.trim();
    }

    private void changePage(int delta) {
        int target = currentPage + delta;
        if (target < 0 || target >= profiles.size()) {
            return;
        }
        currentPage = target;
        renderMain();
    }

    private void renderEmptyState() {
        list.removeAllViews();
        LinearLayout empty = new LinearLayout(this);
        empty.setOrientation(LinearLayout.VERTICAL);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dp(22), dp(54), dp(22), dp(54));
        empty.setBackground(rounded(COLOR_SURFACE, dp(28), Color.rgb(48, 48, 52), dp(1)));

        TextView icon = new TextView(this);
        icon.setText("◉");
        icon.setTextSize(52);
        icon.setTextColor(COLOR_BLUE);
        icon.setGravity(Gravity.CENTER);
        empty.addView(icon);

        TextView title = new TextView(this);
        title.setText(i18n.t("emptyTitle"));
        title.setTextSize(22);
        title.setTextColor(COLOR_TEXT);
        title.setGravity(Gravity.CENTER);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        empty.addView(title);

        TextView body = new TextView(this);
        body.setText(i18n.t("emptyBody"));
        body.setTextSize(15);
        body.setTextColor(COLOR_MUTED);
        body.setGravity(Gravity.CENTER);
        body.setPadding(0, dp(8), 0, dp(18));
        empty.addView(body);

        Button add = filledButton(i18n.t("add"));
        add.setOnClickListener(v -> showEditor(null));
        empty.addView(add, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));

        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(88), 0, 0);
        list.addView(empty, params);
    }

    // One full-screen card page (iOS-style). No surrounding buttons: tap a platform
    // button to switch its QR, tap elsewhere to flip, swipe horizontally to change card.
    private LinearLayout pageView(MeQrProfile profile, int index) {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(18), dp(8), dp(18), dp(90));

        final int[] selectedQr = new int[]{0};
        final boolean[] showingBack = new boolean[]{false};

        ImageView card = new ImageView(this);
        card.setAdjustViewBounds(true);
        card.setScaleType(ImageView.ScaleType.FIT_CENTER);
        card.setImageBitmap(CardRenderer.render(profile, i18n, 900, selectedQr[0]));
        card.setContentDescription(i18n.t("viewBack"));
        card.setClickable(true);

        Runnable renderCard = () -> {
            card.setImageBitmap(showingBack[0]
                    ? CardRenderer.renderBack(profile, i18n, 900)
                    : CardRenderer.render(profile, i18n, 900, selectedQr[0]));
            card.setContentDescription(i18n.t(showingBack[0] ? "viewFront" : "viewBack"));
        };

        GestureDetector detector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onDown(MotionEvent e) {
                return true;
            }

            @Override
            public boolean onSingleTapUp(MotionEvent e) {
                if (!showingBack[0] && profile.qrItems.size() > 1 && card.getWidth() > 0) {
                    float scale = 900f / card.getWidth();
                    float bx = e.getX() * scale;
                    float by = e.getY() * scale;
                    List<RectF> rects = CardRenderer.platformHitRects(profile, i18n, 900);
                    for (int i = 0; i < profile.qrItems.size() && i < rects.size(); i++) {
                        if (rects.get(i).contains(bx, by)) {
                            if (i != selectedQr[0]) {
                                selectedQr[0] = i;
                                renderCard.run();
                            }
                            return true;
                        }
                    }
                }
                showingBack[0] = !showingBack[0];
                renderCard.run();
                return true;
            }

            @Override
            public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
                if (e1 == null || e2 == null) {
                    return false;
                }
                if (Math.abs(velocityX) > Math.abs(velocityY) * 1.4f
                        && Math.abs(e2.getX() - e1.getX()) > dp(48)) {
                    changePage(velocityX < 0 ? 1 : -1);
                    return true;
                }
                return false;
            }
        });
        card.setOnTouchListener((v, e) -> {
            detector.onTouchEvent(e);
            if (e.getAction() == MotionEvent.ACTION_UP) {
                v.performClick();
            }
            return true;
        });

        LinearLayout cardHolder = new LinearLayout(this);
        cardHolder.setGravity(Gravity.CENTER);
        cardHolder.addView(card, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        page.addView(cardHolder, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        if (profiles.size() > 1) {
            LinearLayout dots = new LinearLayout(this);
            dots.setOrientation(LinearLayout.HORIZONTAL);
            dots.setGravity(Gravity.CENTER);
            dots.setPadding(0, dp(12), 0, dp(2));
            for (int i = 0; i < profiles.size(); i++) {
                boolean selected = i == currentPage;
                View dot = new View(this);
                dot.setBackground(rounded(selected ? Color.argb(235, 20, 20, 20) : Color.argb(90, 20, 20, 20), dp(4)));
                LinearLayout.LayoutParams dotParams = new LinearLayout.LayoutParams(dp(selected ? 18 : 8), dp(8));
                dotParams.setMargins(dp(4), 0, dp(4), 0);
                final int target = i;
                dot.setOnClickListener(v -> {
                    if (target != currentPage) {
                        currentPage = target;
                        renderMain();
                    }
                });
                dots.addView(dot, dotParams);
            }
            page.addView(dots);
        }

        return page;
    }

    private void showEditor(MeQrProfile existing) {
        editingProfile = existing;
        editSession = new EditSession(existing == null ? new MeQrProfile() : copy(existing));
        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(COLOR_BG);

        LinearLayout topBar = new LinearLayout(this);
        topBar.setGravity(Gravity.CENTER_VERTICAL);
        topBar.setPadding(dp(18), statusTop() + dp(10), dp(18), dp(8));
        topBar.setOrientation(LinearLayout.HORIZONTAL);

        Button cancel = iconButton("×");
        cancel.setTextSize(22);
        cancel.setContentDescription(i18n.t("cancel"));
        cancel.setOnClickListener(v -> confirmDiscard(dialog::dismiss));
        topBar.addView(cancel, new LinearLayout.LayoutParams(dp(44), dp(44)));

        TextView title = new TextView(this);
        title.setText(existing == null ? i18n.t("newProfile") : i18n.t("editProfile"));
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(22);
        title.setGravity(Gravity.CENTER_VERTICAL);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setPadding(dp(14), 0, 0, 0);
        topBar.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        Button save = filledButton(i18n.t("save"));
        save.setOnClickListener(v -> {
            if (saveEdit()) dialog.dismiss();
        });
        topBar.addView(save, new LinearLayout.LayoutParams(dp(82), dp(44)));
        page.addView(topBar);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        form.setPadding(dp(18), dp(8), dp(18), dp(36));
        scroll.addView(form);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        form.addView(section(i18n.t("preview")));
        LinearLayout previewPanel = panel();
        previewPanel.setGravity(Gravity.CENTER);
        editSession.preview = new ImageView(this);
        editSession.preview.setAdjustViewBounds(true);
        editSession.preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
        editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720, editSession.selectedQrIndex));
        previewPanel.addView(editSession.preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(360)));
        form.addView(previewPanel);

        form.addView(section(i18n.t("profileName")));
        LinearLayout infoPanel = panel();

        editSession.name = field(i18n.t("profileName"), editSession.profile.name, false);
        infoPanel.addView(editSession.name);
        infoPanel.addView(separator());

        editSession.subtitle = field(i18n.t("bio"), editSession.profile.subtitle, true);
        infoPanel.addView(editSession.subtitle);
        form.addView(infoPanel);

        form.addView(section(i18n.t("template")));
        LinearLayout templatePanel = panel();
        LinearLayout templateControl = new LinearLayout(this);
        templateControl.setOrientation(LinearLayout.HORIZONTAL);
        templateControl.setBaselineAligned(false);
        templateControl.setPadding(dp(6), dp(6), dp(6), dp(6));
        Button standard = templateButton(i18n.t("standardTemplate"), "standard".equals(editSession.profile.template));
        Button rhodes = templateButton(i18n.t("rhodesTemplate"), "rhodes".equals(editSession.profile.template));
        editSession.passSubtitle = field(i18n.t("passSubtitleLabel"), editSession.profile.passSubtitle, false);
        TextView passHint = Ui.text(this, i18n.t("passSubtitleHint"), COLOR_MUTED, 12);
        passHint.setPadding(dp(4), dp(6), dp(4), 0);
        boolean rhodesSelected = "rhodes".equals(editSession.profile.template);
        editSession.passSubtitle.setVisibility(rhodesSelected ? View.VISIBLE : View.GONE);
        passHint.setVisibility(rhodesSelected ? View.VISIBLE : View.GONE);
        standard.setOnClickListener(v -> {
            editSession.profile.template = "standard";
            styleTemplateButtons(standard, rhodes);
            editSession.passSubtitle.setVisibility(View.GONE);
            passHint.setVisibility(View.GONE);
            updatePreview();
        });
        rhodes.setOnClickListener(v -> {
            editSession.profile.template = "rhodes";
            styleTemplateButtons(rhodes, standard);
            editSession.passSubtitle.setVisibility(View.VISIBLE);
            passHint.setVisibility(View.VISIBLE);
            updatePreview();
        });
        standard.setMinimumHeight(dp(48));
        rhodes.setMinimumHeight(dp(48));
        templateControl.addView(standard, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        LinearLayout.LayoutParams templateParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        templateParams.setMargins(dp(6), 0, 0, 0);
        templateControl.addView(rhodes, templateParams);
        templatePanel.addView(templateControl);
        templatePanel.addView(editSession.passSubtitle);
        templatePanel.addView(passHint);
        form.addView(templatePanel);

        form.addView(section(i18n.t("platformCards")));
        editSession.qrItemsPanel = new LinearLayout(this);
        editSession.qrItemsPanel.setOrientation(LinearLayout.VERTICAL);
        form.addView(editSession.qrItemsPanel);
        rebuildQrItemsPanel();
        Button addPlatform = filledButton("＋ " + i18n.t("addPlatform"));
        addPlatform.setOnClickListener(v -> {
            editSession.profile.qrItems.add(new MeQrItem());
            editSession.selectedQrIndex = editSession.profile.qrItems.size() - 1;
            rebuildQrItemsPanel();
            updatePreview();
        });
        LinearLayout.LayoutParams addPlatformParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
        addPlatformParams.setMargins(0, dp(10), 0, 0);
        form.addView(addPlatform, addPlatformParams);

        form.addView(section(i18n.t("tags")));
        form.addView(createTagInput(null));

        form.addView(section(i18n.t("tagColors")));
        editSession.tagColorPanel = new LinearLayout(this);
        editSession.tagColorPanel.setOrientation(LinearLayout.VERTICAL);
        form.addView(editSession.tagColorPanel);
        rebuildTagColorPanel();
        rebuildSelectedTagChips(editSession.tagChips);

        form.addView(section(i18n.t("avatar")));
        LinearLayout avatarPanel = panel();
        Button avatar = actionButton(i18n.t("chooseImage"));
        avatar.setOnClickListener(v -> chooseImage(PICK_AVATAR));
        avatarPanel.addView(avatar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        avatarPanel.addView(separator());
        Button removeAvatar = quietButton(i18n.t("removeImage"));
        removeAvatar.setOnClickListener(v -> {
            editSession.profile.avatarPath = "";
            updatePreview();
            toast(i18n.t("done"));
        });
        avatarPanel.addView(removeAvatar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        form.addView(avatarPanel);

        form.addView(section(i18n.t("backgroundImage")));
        LinearLayout backgroundPanel = panel();
        Button background = actionButton(i18n.t("chooseImage"));
        background.setOnClickListener(v -> chooseImage(PICK_BACKGROUND));
        backgroundPanel.addView(background, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        backgroundPanel.addView(separator());
        Button removeBackground = quietButton(i18n.t("removeImage"));
        removeBackground.setOnClickListener(v -> {
            editSession.profile.backgroundPath = "";
            updatePreview();
            toast(i18n.t("done"));
        });
        backgroundPanel.addView(removeBackground, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        backgroundPanel.addView(separator());
        Button banner = actionButton(i18n.t("bannerImage") + " · " + i18n.t("chooseImage"));
        banner.setOnClickListener(v -> chooseImage(PICK_BANNER));
        backgroundPanel.addView(banner, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        backgroundPanel.addView(separator());
        Button removeBanner = quietButton(i18n.t("removeImage") + " · " + i18n.t("bannerImage"));
        removeBanner.setOnClickListener(v -> {
            editSession.profile.bannerPath = "";
            updatePreview();
            toast(i18n.t("done"));
        });
        backgroundPanel.addView(removeBanner, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        form.addView(backgroundPanel);

        form.addView(section(i18n.t("appearance")));
        LinearLayout appearancePanel = panel();
        editSession.textColor = addColorRow(appearancePanel, i18n.t("textColor"), editSession.profile.textColor);
        appearancePanel.addView(separator());
        editSession.qrColor = addColorRow(appearancePanel, i18n.t("qrColor"), editSession.profile.qrColor);
        appearancePanel.addView(separator());
        editSession.backgroundColor = addColorRow(appearancePanel, i18n.t("backgroundColor"), editSession.profile.backgroundColor);
        appearancePanel.addView(separator());
        editSession.borderColor = addColorRow(appearancePanel, i18n.t("borderColor"), editSession.profile.borderColor);
        appearancePanel.addView(separator());

        TextView radiusValue = panelLabel(i18n.t("cornerRadius") + ": " + editSession.profile.cornerRadius);
        appearancePanel.addView(radiusValue);
        SeekBar radius = new SeekBar(this);
        styleSeek(radius);
        radius.setMax(64);
        radius.setProgress(editSession.profile.cornerRadius);
        radius.setOnSeekBarChangeListener(simpleSeek(value -> {
            editSession.profile.cornerRadius = value;
            radiusValue.setText(i18n.t("cornerRadius") + ": " + value);
            updatePreview();
        }));
        appearancePanel.addView(radius);
        appearancePanel.addView(separator());

        TextView opacityValue = panelLabel(i18n.t("opacity") + ": " + Math.round(editSession.profile.cardOpacity * 100) + "%");
        appearancePanel.addView(opacityValue);
        SeekBar opacity = new SeekBar(this);
        styleSeek(opacity);
        opacity.setMax(15);
        opacity.setProgress(Math.round((Math.max(0.25f, editSession.profile.cardOpacity) * 100 - 25) / 5));
        opacity.setOnSeekBarChangeListener(simpleSeek(value -> {
            editSession.profile.cardOpacity = (25 + value * 5) / 100f;
            opacityValue.setText(i18n.t("opacity") + ": " + Math.round(editSession.profile.cardOpacity * 100) + "%");
            updatePreview();
        }));
        appearancePanel.addView(opacity);
        form.addView(appearancePanel);
        attachPreviewUpdates();

        dialog.setContentView(page);
        handleDialogBack(dialog, () -> confirmDiscard(dialog::dismiss));
        dialog.setOnDismissListener(d -> {
            editingProfile = null;
            editSession = null;
        });
        dialog.show();
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(COLOR_BG));
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        }
    }

    private boolean saveEdit() {
        if (!commitTagDraft()) return false;
        MeQrProfile profile = editSession.profile;
        applyEditFields(profile);
        for (String tag : profile.tags) {
            if (!editSession.recordedTagKeys.contains(CardTagIndex.canonicalKey(tag))) recordTagUse(tag);
        }
        for (MeQrItem item : profile.qrItems) {
            if ("custom".equals(item.platform) && item.customPlatformName.trim().isEmpty()) {
                item.platform = PlatformNames.detect(item.qrContent);
            }
            if ("custom".equals(item.platform) && !item.customPlatformName.trim().isEmpty()) {
                String matched = PlatformNames.matchingName(item.customPlatformName, i18n);
                if (matched != null) {
                    item.platform = matched;
                    item.customPlatformName = "";
                }
            }
        }
        profile.syncLegacyFields();
        List<MeQrProfile> updated = new ArrayList<>(profiles);
        if (editingProfile == null) {
            updated.add(profile);
        } else {
            int index = updated.indexOf(editingProfile);
            if (index >= 0) {
                updated.set(index, profile);
            }
        }
        try { store.save(updated); }
        catch (IOException error) { toast(i18n.t("saveFailed")); return false; }
        profiles.clear();
        profiles.addAll(updated);
        currentPage = profiles.indexOf(profile);
        showingCardList = false;
        renderMain();
        return true;
    }

    private void applyEditFields(MeQrProfile profile) {
        if (editSession.name != null) {
            profile.name = value(editSession.name, i18n.t("appName"));
        }
        if (editSession.subtitle != null) {
            profile.subtitle = value(editSession.subtitle, "");
        }
        if (editSession.passSubtitle != null) {
            profile.passSubtitle = limitPassSubtitle(value(editSession.passSubtitle, ""));
        }
        if (editSession.textColor != null) {
            profile.textColor = value(editSession.textColor, "#111111");
        }
        if (editSession.qrColor != null) {
            profile.qrColor = value(editSession.qrColor, "#111111");
        }
        if (editSession.backgroundColor != null) {
            profile.backgroundColor = value(editSession.backgroundColor, "#FFFFFF");
        }
        if (editSession.borderColor != null) {
            profile.borderColor = value(editSession.borderColor, "#111111");
        }
        pruneTagOverrides(profile);
        profile.syncLegacyFields();
    }

    private void rebuildTagColorPanel() {
        if (editSession != null) rebuildSelectedTagChips(editSession.tagChips);
        if (editSession == null || editSession.tagColorPanel == null || editSession.tags == null) {
            return;
        }
        editSession.tagColorPanel.removeAllViews();
        List<String> tags = currentTags();
        if (tags.isEmpty()) {
            TextView hint = Ui.text(this, i18n.t("tagColorsHint"), COLOR_MUTED, 13);
            hint.setPadding(dp(4), 0, 0, 0);
            editSession.tagColorPanel.addView(hint);
            return;
        }
        LinearLayout panel = panel();
        for (int i = 0; i < tags.size(); i++) {
            String tag = tags.get(i);
            if (i > 0) {
                panel.addView(separator());
            }
            addTagColorRow(panel, tag);
        }
        editSession.tagColorPanel.addView(panel);
    }

    private void addTagColorRow(LinearLayout parent, String tag) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(dp(12), dp(5), dp(8), dp(5));

        TextView label = Ui.boldText(this, "# " + tag, COLOR_TEXT, 15);
        label.setTypeface(TagTextWeight.typeface(editSession.profile.tagTextWeight(tag)));
        label.setMaxLines(2);
        label.setEllipsize(android.text.TextUtils.TruncateAt.END);
        label.setGravity(Gravity.CENTER_VERTICAL);
        row.addView(label, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        Button weightButton = tagWeightButton(tag, editSession.profile.tagTextWeight(tag));
        weightButton.setOnClickListener(v -> {
            editSession.profile.setTagTextWeight(tag, TagTextWeight.next(editSession.profile.tagTextWeight(tag)));
            rebuildTagColorPanel();
            updatePreview();
        });
        row.addView(weightButton, new LinearLayout.LayoutParams(dp(44), dp(44)));

        View swatch = new View(this);
        int[] colors = editSession.profile.tagColors(tag);
        swatch.setBackground(tagColorDrawable(colors, dp(10)));
        LinearLayout.LayoutParams swatchParams = new LinearLayout.LayoutParams(dp(40), dp(24));
        swatchParams.setMargins(dp(8), 0, dp(8), 0);
        row.addView(swatch, swatchParams);

        boolean presetMulti = false;
        boolean presetSingle = false;
        if (presetSingle) {
            TextView presetLabel = Ui.text(this, i18n.t("presetColor"), COLOR_MUTED, 13);
            presetLabel.setGravity(Gravity.CENTER);
            row.addView(presetLabel, new LinearLayout.LayoutParams(dp(72), dp(36)));
        } else {
            String actionLabel = colors.length > 1 ? i18n.t("mixedColor") : i18n.t("solidColor");
            Button edit = smallButton(actionLabel);
            edit.setTextColor(Ui.SKY);
            edit.setBackground(rounded(Color.argb(22, 161, 209, 234), dp(9), Color.argb(90, 161, 209, 234), dp(1)));
            edit.setOnClickListener(v -> showTagColorEditor(tag));
            row.addView(edit, new LinearLayout.LayoutParams(dp(72), dp(36)));
        }

        row.setMinimumHeight(dp(56));
        parent.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    }

    private Button tagWeightButton(String tag, int weight) {
        Button button = smallButton("B");
        button.setPadding(0, 0, 0, 0);
        button.setMinWidth(0);
        button.setMinimumWidth(0);
        button.setTypeface(TagTextWeight.typeface(weight));
        button.setTextColor(weight == TagTextWeight.REGULAR ? COLOR_MUTED : Ui.TEAL);
        button.setBackground(rounded(Color.TRANSPARENT, dp(8), COLOR_SEPARATOR, dp(1)));
        String description = tag + ", " + i18n.t("tagTextWeight") + ": " + i18n.t(TagTextWeight.labelKey(weight));
        button.setContentDescription(description);
        button.setTooltipText(description);
        return button;
    }

    private void showTagLibrary() {
        showTagLibrary(null);
    }

    private void showTagLibrary(Runnable onDismiss) {
        if (editSession == null || editSession.tags == null) {
            return;
        }
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(16), dp(12), dp(16), dp(12));
        root.setBackgroundColor(COLOR_BG);

        EditText search = field(i18n.t("searchTags"), editSession.tags.getText().toString().trim(), false);
        search.setBackground(rounded(COLOR_PANEL, dp(12), COLOR_SEPARATOR, dp(1)));
        root.addView(search, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));

        TextView hint = Ui.text(this, RemoteTagCatalog.sourceName(i18n) + " · " + RemoteTagCatalog.revision(), COLOR_MUTED, 12);
        hint.setPadding(dp(4), dp(9), dp(4), dp(8));
        LinearLayout metadata = new LinearLayout(this);
        metadata.setGravity(Gravity.CENTER_VERTICAL);
        metadata.addView(hint, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        metadata.addView(tagIcon(android.R.drawable.ic_menu_info_details, i18n.t("tagCatalogInfo"), this::showTagCatalogInfo));
        metadata.addView(tagIcon(android.R.drawable.ic_menu_add, i18n.t("tagRequestNew"), () -> TagReport.showNew(this, i18n, search.getText().toString())));
        metadata.addView(tagIcon(android.R.drawable.ic_menu_send, i18n.t("tagOutbox"), () -> TagReportOutbox.show(this, i18n)));
        root.addView(metadata);

        RadioGroup modes = new RadioGroup(this);
        modes.setOrientation(LinearLayout.HORIZONTAL);
        modes.setPadding(dp(3), dp(3), dp(3), dp(3));
        modes.setBackground(rounded(COLOR_PANEL, dp(8)));
        String[] labels = {"tagAll", "tagRecent", "tagFrequent", "tagFavorites"};
        for (int i = 0; i < labels.length; i++) {
            RadioButton button = new RadioButton(this);
            button.setId(View.generateViewId());
            button.setTag(i);
            button.setText(i18n.t(labels[i]));
            button.setTextSize(13);
            button.setMinWidth(0);
            button.setButtonDrawable(null);
            button.setGravity(Gravity.CENTER);
            button.setPadding(dp(3), 0, dp(3), 0);
            modes.addView(button, new LinearLayout.LayoutParams(0, dp(48), 1));
        }
        modes.check(modes.getChildAt(0).getId());
        root.addView(modes);

        ScrollView scroll = new ScrollView(this);
        LinearLayout results = new LinearLayout(this);
        results.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(results);
        addCappedScrollView(root, scroll, 0.55);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("tagLibrary"))
                .setView(root)
                .setNegativeButton(i18n.t("done"), null)
                .create();
        Runnable refresh = new Runnable() {
            @Override public void run() {
                hint.setText(RemoteTagCatalog.sourceName(i18n) + " · " + RemoteTagCatalog.revision());
                View selectedMode = modes.findViewById(modes.getCheckedRadioButtonId());
                int mode = (Integer) selectedMode.getTag();
                for (int i = 0; i < modes.getChildCount(); i++) {
                    RadioButton button = (RadioButton) modes.getChildAt(i);
                    button.setTextColor(i == mode ? Ui.TEAL : COLOR_MUTED);
                    button.setBackground(rounded(i == mode ? Color.argb(30, 57, 197, 187) : Color.TRANSPARENT, dp(6)));
                }
                if (mode == 0) rebuildTagLibraryResults(results, search.getText().toString(), dialog);
                else rebuildTagHistory(results, search.getText().toString(), mode, this);
            }
        };
        modes.setOnCheckedChangeListener((group, checkedId) -> refresh.run());
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { refresh.run(); }
            @Override public void afterTextChanged(Editable s) { }
        });
        dialog.setOnDismissListener(ignored -> {
            if (onDismiss != null) {
                onDismiss.run();
            }
        });
        dialog.show();
        styleAlert(dialog);
        refresh.run();
        RemoteTagCatalog.refresh(this, false, refresh);
    }

    private ImageButton tagIcon(int resource, String label, Runnable action) {
        ImageButton button = new ImageButton(this);
        button.setImageResource(resource);
        button.setImageTintList(ColorStateList.valueOf(COLOR_MUTED));
        button.setBackgroundColor(Color.TRANSPARENT);
        button.setContentDescription(label);
        button.setTooltipText(label);
        button.setLayoutParams(new LinearLayout.LayoutParams(dp(48), dp(48)));
        button.setOnClickListener(v -> action.run());
        return button;
    }

    private void rebuildTagHistory(LinearLayout results, String query, int mode, Runnable refresh) {
        results.removeAllViews();
        CardTagUsageStore store = new CardTagUsageStore(this);
        List<CardTagUsageStore.Record> history = mode == 3 ? store.favorites() : store.records(mode == 2);
        int shown = 0;
        String key = CardTagIndex.normalizedKey(query);
        for (CardTagUsageStore.Record record : history.subList(0, mode == 3 ? history.size() : Math.min(20, history.size()))) {
            String tag = record.display(i18n);
            if (!CardTagIndex.normalizedKey(tag).contains(key)) continue;
            addTagLibraryRow(results, tag, refresh);
            shown++;
        }
        if (shown == 0) {
            TextView empty = Ui.text(this, i18n.t(key.isEmpty() ? "tagHistoryEmpty" : "noTagResults"), COLOR_MUTED, 14);
            empty.setPadding(dp(8), dp(20), dp(8), dp(20));
            results.addView(empty);
        }
        if (mode != 3 && !history.isEmpty()) {
            Button clear = quietButton(i18n.t("tagClearHistory"));
            clear.setOnClickListener(v -> {
                AlertDialog confirm = new AlertDialog.Builder(this)
                        .setTitle(i18n.t("tagClearHistory"))
                        .setNegativeButton(i18n.t("cancel"), null)
                        .setPositiveButton(i18n.t("tagClearHistory"), (d, which) -> { store.clear(); refresh.run(); })
                        .show();
                styleAlert(confirm);
            });
            results.addView(clear, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        }
    }

    private void showTagCatalogInfo() {
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(20), dp(12), dp(20), dp(20));
        content.addView(Ui.boldText(this, RemoteTagCatalog.revision(), COLOR_TEXT, 17));
        content.addView(Ui.text(this, RemoteTagCatalog.sourceName(i18n), COLOR_MUTED, 14));
        if (RemoteTagCatalog.statusKey() != null) content.addView(Ui.text(this, i18n.t(RemoteTagCatalog.statusKey()), COLOR_MUTED, 13));
        content.addView(section(i18n.t("tagCatalogChanges")));
        if (RemoteTagCatalog.changelog().isEmpty()) {
            content.addView(Ui.text(this, i18n.t("tagCatalogNoChanges"), COLOR_MUTED, 14));
        }
        for (RemoteTagCatalog.Change change : RemoteTagCatalog.changelog()) {
            content.addView(Ui.boldText(this, change.revision + " · " + change.date, COLOR_TEXT, 15));
            TextView summary = Ui.text(this, change.display(i18n.resolvedLanguage()), COLOR_TEXT, 14);
            summary.setPadding(0, dp(8), 0, dp(16));
            content.addView(summary);
        }
        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle(i18n.t("tagCatalogInfo"))
                .setView(scroll).setPositiveButton(i18n.t("done"), null).show();
        styleAlert(dialog);
    }

    private void rebuildTagLibraryResults(LinearLayout results, String query, AlertDialog dialog) {
        results.removeAllViews();
        List<String> existing = currentTags();

        if (query.trim().isEmpty()) {
            List<RemoteTagCatalog.Category> categories = CardTagIndex.categories();
            if (!categories.isEmpty()) {
                TextView heading = Ui.text(this, i18n.t("tagCategories"), COLOR_MUTED, 13);
                heading.setPadding(dp(4), dp(4), dp(4), dp(8));
                results.addView(heading);
                for (int index = 0; index < categories.size(); index++) {
                    RemoteTagCatalog.Category category = categories.get(index);
                    List<RemoteTagCatalog.Entry> entries = CardTagIndex.entriesIn(category);
                    if (entries.size() == 1) {
                        String tag = entries.get(0).display(i18n.resolvedLanguage());
                        addTagLibraryRow(results, tag, () -> rebuildTagLibraryResults(results, "", dialog));
                    } else {
                        addTagCategoryRow(results, category, entries.size(), dialog);
                    }
                }
                return;
            }
            if (RemoteTagCatalog.isLoading()) {
                TextView loading = Ui.text(this, i18n.t("tagCatalogLoading"), COLOR_MUTED, 14);
                loading.setGravity(Gravity.CENTER);
                results.addView(loading, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(84)));
                return;
            }
        }

        List<String> matches = CardTagIndex.suggestions(query, i18n, existing, 8);
        if (matches.isEmpty()) {
            String message;
            if (existing.size() >= 10) {
                message = i18n.t("tagLimitReached");
            } else if (RemoteTagCatalog.isLoading()) {
                message = i18n.t("tagCatalogLoading");
            } else if (RemoteTagCatalog.errorMessage() != null) {
                message = i18n.t("tagCatalogRetry");
            } else {
                message = i18n.t("searchTags");
            }
            TextView empty = Ui.text(this, message, COLOR_MUTED, 14);
            empty.setGravity(Gravity.CENTER);
            if (RemoteTagCatalog.errorMessage() != null) {
                empty.setTextColor(Ui.TEAL);
                empty.setOnClickListener(v -> {
                    RemoteTagCatalog.refresh(this, true, () -> rebuildTagLibraryResults(results, query, dialog));
                    rebuildTagLibraryResults(results, query, dialog);
                });
            }
            results.addView(empty, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(84)));
            return;
        }
        for (int index = 0; index < matches.size(); index++) {
            String tag = matches.get(index);
            addTagLibraryRow(results, tag, () -> rebuildTagLibraryResults(results, query, dialog));
        }
    }

    private void addTagCategoryRow(LinearLayout parent, RemoteTagCatalog.Category category, int entryCount, AlertDialog dialog) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), 0, dp(8), 0);
        row.setBackground(rounded(COLOR_PANEL, dp(11), COLOR_SEPARATOR, dp(1)));

        TextView name = Ui.boldText(this, category.display(i18n.resolvedLanguage()), COLOR_TEXT, 15);
        name.setPadding(dp(12), 0, dp(8), 0);
        row.addView(name, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        TextView count = Ui.text(this, String.valueOf(entryCount), COLOR_MUTED, 13);
        count.setGravity(Gravity.CENTER);
        count.setPadding(dp(8), 0, 0, 0);
        row.addView(count);

        ImageView chevron = UiIcons.view(this, "›", COLOR_MUTED);
        row.addView(chevron, new LinearLayout.LayoutParams(dp(30), dp(36)));

        row.setOnClickListener(v -> showTagCategory(dialog, (LinearLayout) row.getParent(), category, 0));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
        params.setMargins(0, 0, 0, dp(6));
        parent.addView(row, params);
    }

    private void addTagLibraryRow(LinearLayout parent, String tag, Runnable onChange) {
        boolean selected = isTagSelected(tag);
        boolean limitReached = !selected && currentTags().size() >= 10;

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), 0, dp(8), 0);
        row.setBackground(rounded(COLOR_PANEL, dp(11), COLOR_SEPARATOR, dp(1)));

        View swatch = new View(this);
        swatch.setBackground(tagColorDrawable(CardTagColorPalette.colorsFor(tag, null), dp(9)));
        row.addView(swatch, new LinearLayout.LayoutParams(dp(42), dp(20)));

        LinearLayout labels = new LinearLayout(this);
        labels.setOrientation(LinearLayout.VERTICAL);
        labels.setPadding(dp(12), dp(6), dp(8), dp(6));
        TextView name = Ui.boldText(this, tag, COLOR_TEXT, 15);
        name.setMaxLines(2);
        name.setEllipsize(android.text.TextUtils.TruncateAt.END);
        labels.addView(name);
        RemoteTagCatalog.Entry catalogEntry = RemoteTagCatalog.entryFor(tag);
        if (catalogEntry != null) labels.addView(Ui.text(this, RemoteTagCatalog.subtitle(catalogEntry, i18n), COLOR_MUTED, 11));
        row.addView(labels, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        CardTagUsageStore usage = new CardTagUsageStore(this);
        if (usage.isFavorite(tag)) {
            ImageView favorite = new ImageView(this);
            favorite.setImageResource(android.R.drawable.btn_star_big_on);
            favorite.setContentDescription(i18n.t("tagFavorites"));
            row.addView(favorite, new LinearLayout.LayoutParams(dp(18), dp(18)));
        }

        ImageView trailing = UiIcons.view(this, selected ? "✓" : "+", selected ? Ui.TEAL : COLOR_MUTED);
        row.addView(trailing, new LinearLayout.LayoutParams(dp(36), dp(36)));

        if (limitReached) {
            row.setAlpha(0.45f);
        }
        row.setOnClickListener(v -> {
            if (toggleTag(tag)) {
                onChange.run();
            }
        });
        row.setOnLongClickListener(v -> {
            android.widget.PopupMenu menu = new android.widget.PopupMenu(this, row);
            menu.getMenu().add(0, 1, 0, i18n.t(usage.isFavorite(tag) ? "tagUnfavorite" : "tagFavorite"));
            menu.getMenu().add(0, 2, 1, i18n.t("tagReport"));
            menu.setOnMenuItemClickListener(item -> {
                if (item.getItemId() == 1) { usage.toggleFavorite(tag); onChange.run(); }
                else TagReport.show(this, i18n, tag);
                return true;
            });
            menu.show();
            return true;
        });
        row.setMinimumHeight(dp(64));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, 0, dp(6));
        parent.addView(row, params);
    }

    private void showTagCategory(AlertDialog dialog, LinearLayout results, RemoteTagCatalog.Category category, int requestedPage) {
        results.removeAllViews();

        Button back = actionButton("‹  " + i18n.t("back"));
        back.setOnClickListener(v -> rebuildTagLibraryResults(results, "", dialog));
        results.addView(back, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));

        List<RemoteTagCatalog.Entry> entries = CardTagIndex.entriesIn(category);
        if (entries.isEmpty()) {
            TextView empty = Ui.text(this, i18n.t("searchTags"), COLOR_MUTED, 14);
            empty.setGravity(Gravity.CENTER);
            results.addView(empty, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(84)));
            return;
        }

        int pageCount = Math.max(1, (entries.size() + TAG_CATEGORY_PAGE_SIZE - 1) / TAG_CATEGORY_PAGE_SIZE);
        int page = Math.max(0, Math.min(requestedPage, pageCount - 1));
        TextView heading = Ui.boldText(this,
                category.display(i18n.resolvedLanguage()) + "   " + (page + 1) + " / " + pageCount,
                COLOR_TEXT, 17);
        heading.setPadding(dp(4), dp(12), dp(4), dp(8));
        results.addView(heading);

        int start = page * TAG_CATEGORY_PAGE_SIZE;
        int end = Math.min(entries.size(), start + TAG_CATEGORY_PAGE_SIZE);
        for (int index = start; index < end; index++) {
            String tag = entries.get(index).display(i18n.resolvedLanguage());
            addTagLibraryRow(results, tag, () -> showTagCategory(dialog, results, category, page));
        }

        if (pageCount > 1) {
            LinearLayout navigation = new LinearLayout(this);
            navigation.setOrientation(LinearLayout.HORIZONTAL);
            navigation.setGravity(Gravity.CENTER_VERTICAL);
            navigation.setPadding(0, dp(4), 0, 0);

            Button previous = quietButton(i18n.t("previousPage"));
            previous.setEnabled(page > 0);
            previous.setAlpha(previous.isEnabled() ? 1f : 0.35f);
            previous.setOnClickListener(v -> showTagCategory(dialog, results, category, page - 1));
            navigation.addView(previous, new LinearLayout.LayoutParams(0, dp(44), 1));

            Button next = quietButton(i18n.t("nextPage"));
            next.setEnabled(page + 1 < pageCount);
            next.setAlpha(next.isEnabled() ? 1f : 0.35f);
            next.setOnClickListener(v -> showTagCategory(dialog, results, category, page + 1));
            LinearLayout.LayoutParams nextParams = new LinearLayout.LayoutParams(0, dp(44), 1);
            nextParams.setMargins(dp(8), 0, 0, 0);
            navigation.addView(next, nextParams);
            results.addView(navigation);
        }
    }

    private LinearLayout createTagInput(Runnable onTagsChanged) {
        editSession.onTagsChanged = onTagsChanged;
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        editSession.tagChips = new TagFlowLayout(this);
        section.addView(editSession.tagChips, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        LinearLayout input = new LinearLayout(this);
        input.setGravity(Gravity.CENTER_VERTICAL);
        input.setBackground(rounded(COLOR_PANEL_2, dp(8)));
        editSession.tags = field(i18n.t("tagsHint"), editSession.tagDraft, false);
        editSession.tags.setSingleLine(true);
        editSession.tags.setTextSize(12);
        editSession.tags.setImeOptions(android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
        editSession.tags.setContentDescription(i18n.t("tags"));
        editSession.tags.setTag("tag-draft");
        editSession.tags.setBackgroundColor(Color.TRANSPARENT);
        input.addView(editSession.tags, new LinearLayout.LayoutParams(0, dp(48), 1));
        editSession.tagCount = Ui.text(this, currentTags().size() + "/10", COLOR_MUTED, 12);
        editSession.tagCount.setGravity(Gravity.CENTER);
        input.addView(editSession.tagCount, new LinearLayout.LayoutParams(dp(42), dp(48)));
        input.addView(tagIcon(android.R.drawable.ic_menu_search, i18n.t("tagLibrary"), () -> showTagLibrary()),
                new LinearLayout.LayoutParams(dp(44), dp(48)));
        LinearLayout.LayoutParams inputParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
        inputParams.topMargin = dp(10);
        section.addView(input, inputParams);
        editSession.tagSuggestions = new LinearLayout(this);
        editSession.tagSuggestions.setOrientation(LinearLayout.VERTICAL);
        section.addView(editSession.tagSuggestions);
        editSession.tags.setOnEditorActionListener((v, action, event) -> {
            if (event != null && event.getKeyCode() == android.view.KeyEvent.KEYCODE_ENTER) {
                if (event.getAction() == android.view.KeyEvent.ACTION_UP) commitTagDraft();
                return true;
            }
            if (action == android.view.inputmethod.EditorInfo.IME_ACTION_DONE
                    || action == android.view.inputmethod.EditorInfo.IME_ACTION_NEXT) {
                commitTagDraft();
                return true;
            }
            return false;
        });
        editSession.tags.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { }
            @Override public void afterTextChanged(Editable s) {
                if (editSession == null || editSession.committingTags
                        || android.view.inputmethod.BaseInputConnection.getComposingSpanStart(s) >= 0) return;
                String text = s.toString();
                if (text.contains("\n") || text.contains(",") || text.contains("，")) commitTagDraft();
                else rebuildTagInputSuggestions();
            }
        });
        rebuildSelectedTagChips(editSession.tagChips);
        rebuildTagInputSuggestions();
        return section;
    }

    private void rebuildTagInputSuggestions() {
        if (editSession == null || editSession.tagSuggestions == null || editSession.tags == null) return;
        LinearLayout results = editSession.tagSuggestions;
        results.removeAllViews();
        String query = editSession.tags.getText().toString().trim();
        if (query.isEmpty() || currentTags().size() >= 10) return;
        for (String tag : CardTagIndex.suggestions(query, i18n, currentTags(), 4)) {
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setMinimumHeight(dp(48));
            row.setPadding(dp(10), dp(6), dp(10), dp(6));
            LinearLayout labels = new LinearLayout(this);
            labels.setOrientation(LinearLayout.VERTICAL);
            labels.addView(Ui.text(this, tag, COLOR_TEXT, 15));
            RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryFor(tag);
            if (entry != null) labels.addView(Ui.text(this, RemoteTagCatalog.subtitle(entry, i18n), COLOR_MUTED, 12));
            row.addView(labels, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            row.addView(UiIcons.view(this, "+", COLOR_BLUE), new LinearLayout.LayoutParams(dp(24), dp(24)));
            row.setContentDescription(i18n.t("add") + " " + tag);
            row.setOnClickListener(view -> {
                if (appendTag(tag)) {
                    editSession.tags.setText("");
                    editSession.tagDraft = "";
                }
            });
            results.addView(row);
        }
    }

    private boolean commitTagDraft() {
        if (editSession == null || editSession.tags == null || editSession.committingTags) return true;
        String raw = editSession.tags.getText().toString();
        if (raw.trim().isEmpty()) return true;
        List<String> selected = currentTags(), remaining = new ArrayList<>();
        for (String part : raw.split("[\\n\\r,，]+")) {
            String tag = part.trim();
            if (tag.isEmpty()) continue;
            String key = CardTagIndex.canonicalKey(tag);
            boolean duplicate = false;
            for (String existing : selected) if (CardTagIndex.canonicalKey(existing).equals(key)) duplicate = true;
            if (duplicate) continue;
            if (selected.size() >= 10) remaining.add(tag);
            else { selected.add(tag); recordTagUse(tag); }
        }
        editSession.committingTags = true;
        editSession.tags.setText(String.join(", ", remaining));
        editSession.tagDraft = editSession.tags.getText().toString();
        editSession.tags.setSelection(editSession.tags.length());
        editSession.committingTags = false;
        writeTags(selected);
        if (!remaining.isEmpty()) toast(i18n.t("tagLimitReached"));
        return remaining.isEmpty();
    }

    private boolean appendTag(String tag) {
        List<String> tags = currentTags();
        if (tags.size() >= 10) {
            toast(i18n.t("tagLimitReached"));
            return false;
        }
        String key = CardTagIndex.canonicalKey(tag);
        for (String existing : tags) {
            if (CardTagIndex.canonicalKey(existing).equals(key)) {
                return false;
            }
        }
        tags.add(tag == null ? "" : tag.trim());
        recordTagUse(tag);
        writeTags(tags);
        return true;
    }

    private boolean toggleTag(String tag) {
        List<String> tags = currentTags();
        String key = CardTagIndex.canonicalKey(tag);
        boolean removed = false;
        for (int index = 0; index < tags.size(); index++) {
            if (CardTagIndex.canonicalKey(tags.get(index)).equals(key)) {
                tags.remove(index);
                removed = true;
                break;
            }
        }
        if (!removed) {
            if (tags.size() >= 10) {
                toast(i18n.t("tagLimitReached"));
                return false;
            }
            tags.add(tag == null ? "" : tag.trim());
            recordTagUse(tag);
        }
        writeTags(tags);
        return true;
    }

    private List<String> currentTags() {
        return new ArrayList<>(editSession.profile.tags);
    }

    private void recordTagUse(String tag) {
        new CardTagUsageStore(this).record(tag);
        editSession.recordedTagKeys.add(CardTagIndex.canonicalKey(tag));
    }

    private void writeTags(List<String> tags) {
        editSession.profile.tags.clear();
        editSession.profile.tags.addAll(tags);
        pruneTagOverrides(editSession.profile);
        rebuildSelectedTagChips(editSession.tagChips);
        rebuildTagColorPanel();
        if (editSession.tagCount != null) editSession.tagCount.setText(tags.size() + "/10");
        rebuildTagInputSuggestions();
        if (editSession.onTagsChanged != null) editSession.onTagsChanged.run();
        updatePreview();
    }

    private boolean isTagSelected(String tag) {
        String key = CardTagIndex.canonicalKey(tag);
        for (String existing : currentTags()) {
            if (CardTagIndex.canonicalKey(existing).equals(key)) {
                return true;
            }
        }
        return false;
    }

    private void showTagColorEditor(String tag) {
        String existingOverride = editSession.profile.tagColorOverrides.get(tag);
        TagReference reference = editSession.profile.referenceFor(tag);
        boolean[] usePreset = new boolean[]{false};
        String[] mode = {reference == null ? CardTagColorPalette.modeFor(tag, existingOverride) : reference.modeFor(existingOverride)};
        List<String> colors = reference == null ? CardTagColorPalette.customColorsFor(tag, existingOverride) : reference.customColorsFor(existingOverride);
        java.util.Map<String, String> pendingCopies = new java.util.HashMap<>();

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(16), dp(8), dp(16), dp(8));
        root.setBackgroundColor(COLOR_BG);

        TextView preview = Ui.boldText(this, tag, Color.WHITE, 14);
        preview.setTypeface(TagTextWeight.typeface(editSession.profile.tagTextWeight(tag)));
        preview.setGravity(Gravity.CENTER);
        preview.setSingleLine(true);
        preview.setEllipsize(android.text.TextUtils.TruncateAt.END);
        preview.setPadding(dp(12), 0, dp(12), 0);
        LinearLayout.LayoutParams previewParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(28));
        previewParams.gravity = Gravity.CENTER_HORIZONTAL;
        root.addView(preview, previewParams);

        LinearLayout modes = new LinearLayout(this);
        modes.setOrientation(LinearLayout.HORIZONTAL);
        root.addView(modes, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        LinearLayout colorRows = new LinearLayout(this);
        colorRows.setOrientation(LinearLayout.VERTICAL);
        root.addView(colorRows);

        rebuildTagColorEditorRows(colorRows, colors, tag, usePreset, preview, pendingCopies);
        String[] values = {"solid", "preset", "custom"};
        String[] labels = {"solidColor", "mixedColor", "customColor"};
        List<Button> buttons = new ArrayList<>();
        Runnable refresh = () -> {
            colorRows.setVisibility(mode[0].equals("custom") ? View.VISIBLE : View.GONE);
            int[] rendered = editSession.profile.tagColors(tag, CardTagColorPalette.encodeMode(mode[0], colors));
            preview.setBackground(tagColorDrawable(rendered, dp(14)));
            new TagTextContrast(rendered).apply(preview);
            for (Button button : buttons) {
                boolean selected = mode[0].equals(button.getTag());
                button.setSelected(selected);
                button.setTextColor(selected ? Color.WHITE : COLOR_TEXT);
                button.setBackground(rounded(selected ? Ui.TEAL : COLOR_PANEL, dp(6), COLOR_SEPARATOR, dp(1)));
            }
        };
        for (int index = 0; index < values.length; index++) {
            if (values[index].equals("preset") && editSession.profile.tagColors(tag, "@preset").length < 2) continue;
            String value = values[index];
            Button button = templateButton(i18n.t(labels[index]), value.equals(mode[0]));
            button.setTag(value);
            button.setTextSize(12);
            button.setPadding(0, 0, 0, 0);
            button.setOnClickListener(v -> { mode[0] = value; refresh.run(); });
            buttons.add(button);
            modes.addView(button, new LinearLayout.LayoutParams(0, dp(44), 1));
        }
        refresh.run();
        ScrollView scroll = new ScrollView(this);
        scroll.addView(root);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("editTagColors"))
                .setView(scroll)
                .setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("save"), (choiceDialog, which) -> {
                    editSession.profile.tagColorOverrides.put(tag, CardTagColorPalette.encodeMode(mode[0], colors));
                    editSession.profile.tagColorOverrides.putAll(pendingCopies);
                    rebuildTagColorPanel();
                    updatePreview();
                })
                .show();
        styleAlert(dialog);
    }

    private void showPresetTagColorEditor(String tag) {
        String existingOverride = editSession.profile.tagColorOverrides.get(tag);
        boolean[] solid = new boolean[]{CardTagColorPalette.isSolidOverride(existingOverride)};
        int[] presetColors = CardTagColorPalette.presetColorsFor(tag);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(10), dp(18), dp(12));
        root.setBackgroundColor(COLOR_BG);

        TextView preview = Ui.boldText(this, "# " + tag, Color.WHITE, 14);
        preview.setGravity(Gravity.CENTER);
        preview.setBackground(tagColorDrawable(solid[0]
                ? new int[]{presetColors[0]}
                : presetColors, dp(12)));
        root.addView(preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));

        LinearLayout modes = new LinearLayout(this);
        modes.setOrientation(LinearLayout.HORIZONTAL);
        modes.setPadding(dp(4), dp(4), dp(4), dp(4));
        modes.setBackground(rounded(COLOR_PANEL, dp(10), COLOR_SEPARATOR, dp(1)));
        Button mixed = templateButton(i18n.t("mixedColor"), !solid[0]);
        Button single = templateButton(i18n.t("solidColor"), solid[0]);
        Runnable refresh = () -> {
            styleTemplateButtons(solid[0] ? single : mixed, solid[0] ? mixed : single);
            preview.setBackground(tagColorDrawable(solid[0]
                    ? new int[]{presetColors[0]}
                    : presetColors, dp(12)));
        };
        mixed.setOnClickListener(v -> {
            solid[0] = false;
            refresh.run();
        });
        single.setOnClickListener(v -> {
            solid[0] = true;
            refresh.run();
        });
        modes.addView(mixed, new LinearLayout.LayoutParams(0, dp(44), 1));
        LinearLayout.LayoutParams singleParams = new LinearLayout.LayoutParams(0, dp(44), 1);
        singleParams.setMargins(dp(6), 0, 0, 0);
        modes.addView(single, singleParams);
        LinearLayout.LayoutParams modeParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        modeParams.setMargins(0, dp(14), 0, 0);
        root.addView(modes, modeParams);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("editTagColors"))
                .setView(root)
                .setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("save"), (choiceDialog, which) -> {
                    if (solid[0]) {
                        editSession.profile.tagColorOverrides.put(tag, CardTagColorPalette.solidOverrideValue());
                    } else {
                        editSession.profile.tagColorOverrides.remove(tag);
                    }
                    rebuildTagColorPanel();
                    updatePreview();
                })
                .show();
        styleAlert(dialog);
    }

    private void rebuildTagColorEditorRows(LinearLayout container, List<String> colors, String tag,
                                           boolean[] usePreset, TextView preview, java.util.Map<String, String> pendingCopies) {
        container.removeAllViews();
        int[] previewColors = usePreset[0]
                ? CardTagColorPalette.colorsFor(tag, null)
                : CardTagColorPalette.colorsFor(tag, CardTagColorPalette.encodeColors(colors));
        preview.setBackground(tagColorDrawable(previewColors, dp(12)));
        new TagTextContrast(previewColors).apply(preview);

        for (int index = 0; index < colors.size(); index++) {
            int colorIndex = index;
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setTag(index);
            ImageButton handle = tagIcon(android.R.drawable.ic_menu_sort_by_size, i18n.t("tagMoveColor"), () -> {
                android.widget.PopupMenu menu = new android.widget.PopupMenu(this, row);
                menu.getMenu().add(0, 1, 0, i18n.t("tagMoveUp")).setEnabled(colorIndex > 0);
                menu.getMenu().add(0, 2, 1, i18n.t("tagMoveDown")).setEnabled(colorIndex < colors.size() - 1);
                menu.setOnMenuItemClickListener(item -> {
                    int target = colorIndex + (item.getItemId() == 1 ? -1 : 1);
                    colors.add(target, colors.remove(colorIndex));
                    rebuildTagColorEditorRows(container, colors, tag, usePreset, preview, pendingCopies);
                    return true;
                });
                menu.show();
            });
            handle.setOnLongClickListener(v -> row.startDragAndDrop(ClipData.newPlainText("MeQR Color", String.valueOf(colorIndex)), new View.DragShadowBuilder(row), row, 0));
            row.addView(handle, new LinearLayout.LayoutParams(dp(32), dp(44)));
            row.setOnDragListener((view, event) -> {
                if (!(event.getLocalState() instanceof View) || ((View) event.getLocalState()).getParent() != container) return false;
                if (event.getAction() == DragEvent.ACTION_DROP) {
                    int from = (Integer) ((View) event.getLocalState()).getTag();
                    colors.add(colorIndex, colors.remove(from));
                    container.post(() -> rebuildTagColorEditorRows(container, colors, tag, usePreset, preview, pendingCopies));
                }
                return true;
            });

            TextView label = Ui.text(this, i18n.t("color") + " " + (index + 1), COLOR_TEXT, 14);
            label.setGravity(Gravity.CENTER_VERTICAL);
            row.addView(label, new LinearLayout.LayoutParams(dp(52), dp(48)));

            EditText field = new EditText(this);
            field.setText(colors.get(index));
            field.setSingleLine(true);
            field.setTextColor(COLOR_TEXT);
            field.setTextSize(14);
            field.setHint(i18n.t("tagHex"));
            field.setContentDescription(i18n.t("tagHex") + " " + (index + 1));
            field.setGravity(Gravity.CENTER);
            field.setBackground(rounded(COLOR_PANEL, dp(10), COLOR_SEPARATOR, dp(1)));
            row.addView(field, new LinearLayout.LayoutParams(0, dp(42), 1));

            View swatch = new View(this);
            swatch.setBackground(rounded(CardTagColorPalette.parseHex(colors.get(index), Ui.TEAL), dp(10), Color.WHITE, dp(1)));
            LinearLayout.LayoutParams swatchParams = new LinearLayout.LayoutParams(dp(36), dp(36));
            swatchParams.setMargins(dp(8), 0, 0, 0);
            row.addView(swatch, swatchParams);
            swatch.setOnClickListener(v -> showPresetColorPicker(selected -> field.setText(selected)));

            if (colors.size() > 1) {
                Button remove = iconButton("×");
                remove.setTextSize(16);
                remove.setOnClickListener(v -> {
                    colors.remove(colorIndex);
                    usePreset[0] = false;
                    rebuildTagColorEditorRows(container, colors, tag, usePreset, preview, pendingCopies);
                });
                LinearLayout.LayoutParams removeParams = new LinearLayout.LayoutParams(dp(36), dp(36));
                removeParams.setMargins(dp(7), 0, 0, 0);
                row.addView(remove, removeParams);
            }

            field.addTextChangedListener(new TextWatcher() {
                @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
                @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                    String normalized = CardTagColorPalette.normalizedHex(s.toString());
                    field.setError(normalized == null ? i18n.t("tagInvalidHex") : null);
                    if (normalized != null) {
                        colors.set(colorIndex, normalized);
                        usePreset[0] = false;
                        swatch.setBackground(rounded(Color.parseColor(normalized), dp(10), Color.WHITE, dp(1)));
                        preview.setBackground(tagColorDrawable(CardTagColorPalette.colorsFor(tag,
                                CardTagColorPalette.encodeColors(colors)), dp(12)));
                        new TagTextContrast(CardTagColorPalette.colorsFor(tag, CardTagColorPalette.encodeColors(colors))).apply(preview);
                    }
                }
                @Override public void afterTextChanged(Editable s) { }
            });
            container.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        }

        if (colors.size() < CardTagColorPalette.MAX_CUSTOM_COLORS) {
            Button add = actionButton("＋  " + i18n.t("addColor"));
            add.setOnClickListener(v -> {
                colors.add(colors.isEmpty() ? "#39C5BB" : colors.get(colors.size() - 1));
                usePreset[0] = false;
                rebuildTagColorEditorRows(container, colors, tag, usePreset, preview, pendingCopies);
            });
            container.addView(add, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(42)));
        }
        if (currentTags().size() > 1) {
            Button copy = actionButton(i18n.t("tagCopyPalette"));
            copy.setCompoundDrawablesWithIntrinsicBounds(android.R.drawable.ic_menu_set_as, 0, 0, 0);
            copy.setOnClickListener(v -> {
                List<String> targets = new ArrayList<>(currentTags());
                targets.remove(tag);
                new AlertDialog.Builder(this).setTitle(i18n.t("tagCopyPalette"))
                        .setItems(targets.toArray(new String[0]), (dialog, which) -> {
                            pendingCopies.put(targets.get(which), CardTagColorPalette.encodeMode("custom", colors));
                            Toast.makeText(this, targets.get(which), Toast.LENGTH_SHORT).show();
                        }).show();
            });
            container.addView(copy);
        }
    }

    private void showPresetColorPicker(ColorChoice choice) {
        int[] palette = {0xFF39C5BB, 0xFF3381B0, 0xFFA1D1EA, 0xFF00A0E9, 0xFF88DD44, 0xFFFF9900,
                0xFFEE1166, 0xFF884499, 0xFFFF66AA, 0xFF66CC99, 0xFFFFCC66, 0xFF6F7582};
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(4);
        grid.setPadding(dp(16), dp(10), dp(16), dp(10));
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("choosePresetColor"))
                .setView(grid)
                .setNegativeButton(i18n.t("cancel"), null)
                .create();
        for (int color : palette) {
            View swatch = new View(this);
            swatch.setBackground(rounded(color, dp(12), Color.WHITE, dp(2)));
            swatch.setOnClickListener(v -> {
                choice.onColor(CardTagColorPalette.hex(color));
                dialog.dismiss();
            });
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = dp(52);
            params.height = dp(52);
            params.setMargins(dp(7), dp(7), dp(7), dp(7));
            grid.addView(swatch, params);
        }
        dialog.show();
        styleAlert(dialog);
    }

    private String hexOf(float[] hsv) {
        return String.format(Locale.US, "#%06X", 0xFFFFFF & Color.HSVToColor(hsv));
    }

    private void showColorPicker(String initialHex, ColorChoice choice) {
        final float[] hsv = new float[3];
        Color.colorToHSV(CardRenderer.parseColor(initialHex, Color.WHITE), hsv);

        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(14), dp(18), dp(6));
        scroll.addView(root);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        final View preview = new View(this);
        preview.setBackground(rounded(Color.HSVToColor(hsv), dp(12), Color.WHITE, dp(2)));
        header.addView(preview, new LinearLayout.LayoutParams(dp(40), dp(40)));
        final EditText hexField = new EditText(this);
        hexField.setText(hexOf(hsv));
        hexField.setSingleLine(true);
        hexField.setTextColor(COLOR_TEXT);
        hexField.setTextSize(16);
        hexField.setInputType(InputType.TYPE_CLASS_TEXT);
        LinearLayout.LayoutParams hexParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        hexParams.setMargins(dp(12), 0, 0, 0);
        header.addView(hexField, hexParams);
        root.addView(header);

        final SatValPanel satVal = new SatValPanel(hsv);
        LinearLayout.LayoutParams svParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(184));
        svParams.setMargins(0, dp(14), 0, dp(14));
        root.addView(satVal, svParams);

        final HuePanel huePanel = new HuePanel(hsv);
        root.addView(huePanel, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(28)));

        final boolean[] syncing = {false};
        final Runnable refresh = () -> {
            int color = Color.HSVToColor(hsv);
            preview.setBackground(rounded(color, dp(12), Color.WHITE, dp(2)));
            satVal.invalidate();
            huePanel.invalidate();
            syncing[0] = true;
            hexField.setText(hexOf(hsv));
            hexField.setSelection(hexField.getText().length());
            syncing[0] = false;
        };
        satVal.onChange = refresh;
        huePanel.onChange = refresh;
        hexField.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable editable) {
                if (syncing[0]) {
                    return;
                }
                String text = editable.toString().trim();
                if (!text.startsWith("#")) {
                    text = "#" + text;
                }
                if (text.length() != 7) {
                    return;
                }
                try {
                    int color = Color.parseColor(text);
                    Color.colorToHSV(color, hsv);
                    preview.setBackground(rounded(color, dp(12), Color.WHITE, dp(2)));
                    satVal.invalidate();
                    huePanel.invalidate();
                } catch (IllegalArgumentException ignored) {
                }
            }
        });

        TextView presetLabel = new TextView(this);
        presetLabel.setText(i18n.t("presets"));
        presetLabel.setTextColor(COLOR_MUTED);
        presetLabel.setTextSize(12);
        presetLabel.setPadding(dp(2), dp(14), 0, dp(6));
        root.addView(presetLabel);

        int[] palette = {0xFF111111, 0xFFFFFFFF, 0xFF39C5BB, 0xFF3381B0, 0xFF00A0E9, 0xFF88DD44,
                0xFFFF9900, 0xFFEE1166, 0xFF884499, 0xFFFF66AA, 0xFF66CC99, 0xFFFFCC66};
        LinearLayout presetRow = new LinearLayout(this);
        presetRow.setOrientation(LinearLayout.HORIZONTAL);
        HorizontalScrollView presetScroll = new HorizontalScrollView(this);
        presetScroll.setHorizontalScrollBarEnabled(false);
        presetScroll.addView(presetRow);
        for (int color : palette) {
            View dot = new View(this);
            dot.setBackground(rounded(color, dp(9), Color.argb(120, 128, 128, 128), dp(1)));
            dot.setOnClickListener(v -> {
                Color.colorToHSV(color, hsv);
                refresh.run();
            });
            LinearLayout.LayoutParams dotParams = new LinearLayout.LayoutParams(dp(34), dp(34));
            dotParams.setMargins(0, 0, dp(10), 0);
            presetRow.addView(dot, dotParams);
        }
        root.addView(presetScroll);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("pickColor"))
                .setView(scroll)
                .setPositiveButton(i18n.t("done"), (d, w) -> choice.onColor(hexOf(hsv)))
                .setNegativeButton(i18n.t("cancel"), null)
                .create();
        dialog.show();
        styleAlert(dialog);
    }

    private final class SatValPanel extends View {
        private final float[] hsv;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        Runnable onChange;

        SatValPanel(float[] hsv) {
            super(MainActivity.this);
            this.hsv = hsv;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            int w = getWidth();
            int h = getHeight();
            if (w == 0 || h == 0) {
                return;
            }
            int hueColor = Color.HSVToColor(new float[]{hsv[0], 1f, 1f});
            paint.setShader(new LinearGradient(0, 0, w, 0, Color.WHITE, hueColor, Shader.TileMode.CLAMP));
            canvas.drawRect(0, 0, w, h, paint);
            paint.setShader(new LinearGradient(0, 0, 0, h, 0x00000000, 0xFF000000, Shader.TileMode.CLAMP));
            canvas.drawRect(0, 0, w, h, paint);
            paint.setShader(null);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(1));
            paint.setColor(Color.argb(60, 128, 128, 128));
            canvas.drawRect(0, 0, w, h, paint);
            float x = hsv[1] * w;
            float y = (1f - hsv[2]) * h;
            paint.setStrokeWidth(dp(2));
            paint.setColor(Color.argb(160, 0, 0, 0));
            canvas.drawCircle(x, y, dp(9), paint);
            paint.setColor(Color.WHITE);
            canvas.drawCircle(x, y, dp(8), paint);
            paint.setStyle(Paint.Style.FILL);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            int w = getWidth();
            int h = getHeight();
            float x = Math.max(0, Math.min(w, event.getX()));
            float y = Math.max(0, Math.min(h, event.getY()));
            hsv[1] = w == 0 ? 0 : x / w;
            hsv[2] = h == 0 ? 0 : 1f - y / h;
            if (onChange != null) {
                onChange.run();
            }
            android.view.ViewParent p = getParent();
            if (p != null) p.requestDisallowInterceptTouchEvent(true);
            return true;
        }
    }

    private final class HuePanel extends View {
        private final float[] hsv;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        Runnable onChange;

        HuePanel(float[] hsv) {
            super(MainActivity.this);
            this.hsv = hsv;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            int w = getWidth();
            int h = getHeight();
            if (w == 0 || h == 0) {
                return;
            }
            int[] colors = new int[7];
            for (int i = 0; i < colors.length; i++) {
                colors[i] = Color.HSVToColor(new float[]{i * 60f, 1f, 1f});
            }
            paint.setShader(new LinearGradient(0, 0, w, 0, colors, null, Shader.TileMode.CLAMP));
            float radius = h / 2f;
            canvas.drawRoundRect(new RectF(0, 0, w, h), radius, radius, paint);
            paint.setShader(null);
            float x = Math.max(radius, Math.min(w - radius, hsv[0] / 360f * w));
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(3));
            paint.setColor(Color.argb(160, 0, 0, 0));
            canvas.drawCircle(x, h / 2f, radius - dp(2), paint);
            paint.setColor(Color.WHITE);
            paint.setStrokeWidth(dp(2));
            canvas.drawCircle(x, h / 2f, radius - dp(3), paint);
            paint.setStyle(Paint.Style.FILL);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            int w = getWidth();
            float x = Math.max(0, Math.min(w, event.getX()));
            hsv[0] = w == 0 ? 0 : x / w * 360f;
            if (hsv[0] >= 360f) {
                hsv[0] = 359.999f;
            }
            if (onChange != null) {
                onChange.run();
            }
            android.view.ViewParent p = getParent();
            if (p != null) p.requestDisallowInterceptTouchEvent(true);
            return true;
        }
    }

    private android.graphics.drawable.Drawable tagColorDrawable(int[] colors, int radius) {
        int[] safeColors = colors == null || colors.length == 0 ? new int[]{Ui.TEAL} : colors;
        return new TagSegmentDrawable(safeColors, radius);
    }

    private List<String> parseTags(String raw) {
        List<String> tags = new ArrayList<>();
        List<String> keys = new ArrayList<>();
        if (raw == null || raw.isEmpty()) {
            return tags;
        }
        for (String part : raw.split("[\\n\\r,，]+", -1)) {
            String tag = part == null ? "" : part.trim();
            String key = CardTagIndex.canonicalKey(tag);
            if (!tag.isEmpty() && !keys.contains(key)) {
                tags.add(tag);
                keys.add(key);
            }
            if (tags.size() >= 10) {
                break;
            }
        }
        return tags;
    }

    private int contrastTextOn(int color) {
        int red = Color.red(color);
        int green = Color.green(color);
        int blue = Color.blue(color);
        double luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        return luminance > 150 ? Color.rgb(20, 20, 20) : Color.WHITE;
    }

    private void rebuildSelectedTagChips(LinearLayout container) {
        if (container == null) {
            return;
        }
        container.removeAllViews();
        List<String> tags = currentTags();
        if (tags.isEmpty()) return;
        for (int index = 0; index < tags.size(); index++) {
            String tag = tags.get(index);
            int[] colors = editSession.profile.tagColors(tag);
            TagTextContrast ink = new TagTextContrast(colors);
            int textColor = ink.foreground;

            LinearLayout chip = new LinearLayout(this);
            chip.setOrientation(LinearLayout.HORIZONTAL);
            chip.setGravity(Gravity.CENTER_VERTICAL);
            chip.setPadding(dp(8), 0, dp(2), 0);
            chip.setBackground(new TagSegmentDrawable(colors, dp(14)));
            chip.setTag(tag);
            chip.setOnLongClickListener(v -> v.startDragAndDrop(
                    ClipData.newPlainText("MeQR Tag", tag), new View.DragShadowBuilder(chip), chip, 0));
            chip.setOnDragListener((target, event) -> {
                if (!(event.getLocalState() instanceof View) || ((View) event.getLocalState()).getParent() != container) return false;
                switch (event.getAction()) {
                    case DragEvent.ACTION_DRAG_STARTED: return true;
                    case DragEvent.ACTION_DRAG_ENTERED: chip.setAlpha(0.55f); return true;
                    case DragEvent.ACTION_DRAG_LOCATION:
                        android.view.ViewParent ancestor = container.getParent();
                        while (ancestor instanceof View && !(ancestor instanceof ScrollView)) ancestor = ancestor.getParent();
                        if (ancestor instanceof ScrollView) {
                            ScrollView scroll = (ScrollView) ancestor;
                            int[] chipLocation = new int[2], scrollLocation = new int[2];
                            chip.getLocationOnScreen(chipLocation);
                            scroll.getLocationOnScreen(scrollLocation);
                            float y = chipLocation[1] + event.getY() - scrollLocation[1];
                            if (y < dp(48)) scroll.smoothScrollBy(0, -dp(12));
                            else if (y > scroll.getHeight() - dp(48)) scroll.smoothScrollBy(0, dp(12));
                        }
                        return true;
                    case DragEvent.ACTION_DROP:
                        String source = (String) ((View) event.getLocalState()).getTag();
                        container.post(() -> moveSelectedTag(source, tag, container));
                        return true;
                    case DragEvent.ACTION_DRAG_EXITED:
                    case DragEvent.ACTION_DRAG_ENDED: chip.setAlpha(1f); return true;
                    default: return true;
                }
            });
            final int moveUp = View.generateViewId(), moveDown = View.generateViewId();
            chip.setAccessibilityDelegate(new View.AccessibilityDelegate() {
                @Override public void onInitializeAccessibilityNodeInfo(View host, android.view.accessibility.AccessibilityNodeInfo info) {
                    super.onInitializeAccessibilityNodeInfo(host, info);
                    info.addAction(new android.view.accessibility.AccessibilityNodeInfo.AccessibilityAction(moveUp, i18n.t("tagMoveUp")));
                    info.addAction(new android.view.accessibility.AccessibilityNodeInfo.AccessibilityAction(moveDown, i18n.t("tagMoveDown")));
                }
                @Override public boolean performAccessibilityAction(View host, int action, Bundle args) {
                    if (action == moveUp || action == moveDown) {
                        List<String> current = currentTags();
                        int from = current.indexOf(tag), to = from + (action == moveUp ? -1 : 1);
                        if (from >= 0 && to >= 0 && to < current.size()) moveSelectedTag(tag, current.get(to), container);
                        return true;
                    }
                    return super.performAccessibilityAction(host, action, args);
                }
            });

            TextView label = Ui.boldText(this, tag, textColor, 14);
            label.setTypeface(TagTextWeight.typeface(editSession.profile.tagTextWeight(tag)));
            ink.apply(label);
            label.setSingleLine(true);
            label.setEllipsize(android.text.TextUtils.TruncateAt.END);
            label.setPadding(0, 0, dp(3), 0);
            chip.addView(label, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

            android.widget.ImageButton remove = new android.widget.ImageButton(this);
            remove.setImageResource(android.R.drawable.ic_menu_close_clear_cancel);
            remove.setColorFilter(textColor);
            remove.setPadding(dp(4), dp(5), dp(4), dp(5));
            remove.setScaleType(ImageView.ScaleType.FIT_CENTER);
            remove.setBackgroundColor(Color.TRANSPARENT);
            remove.setContentDescription(i18n.t("delete") + " " + tag);
            remove.setOnClickListener(v -> {
                List<String> current = currentTags();
                current.remove(tag);
                writeTags(current);
                rebuildSelectedTagChips(container);
            });
            chip.addView(remove, new LinearLayout.LayoutParams(dp(26), dp(28)));

            LinearLayout.LayoutParams chipParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(28));
            container.addView(chip, chipParams);
        }
    }

    private void moveSelectedTag(String source, String target, LinearLayout container) {
        List<String> ordered = currentTags();
        int destination = ordered.indexOf(target);
        if (source.equals(target) || destination < 0 || !ordered.remove(source)) return;
        ordered.add(destination, source);
        writeTags(ordered);
        rebuildSelectedTagChips(container);
    }

    private void rebuildOnboardingSuggestions(LinearLayout container, LinearLayout chipsContainer) {
        if (container == null) {
            return;
        }
        container.removeAllViews();
        List<String> featured = CardTagIndex.featuredSuggestions(i18n, 8);
        if (featured.isEmpty()) {
            TextView empty = Ui.text(this, RemoteTagCatalog.isLoading()
                    ? i18n.t("tagCatalogLoading")
                    : i18n.t("tagCatalogRetry"), COLOR_MUTED, 13);
            empty.setPadding(dp(4), dp(2), dp(4), dp(2));
            container.addView(empty);
            return;
        }
        for (int index = 0; index < featured.size(); index++) {
            String tag = featured.get(index);
            boolean selected = false;
            String key = CardTagIndex.canonicalKey(tag);
            for (String existing : editSession.profile.tags) {
                if (CardTagIndex.canonicalKey(existing).equals(key)) {
                    selected = true;
                    break;
                }
            }
            int color = CardTagColorPalette.colorFor(tag);
            int textColor = contrastTextOn(color);

            LinearLayout chip = new LinearLayout(this);
            chip.setOrientation(LinearLayout.HORIZONTAL);
            chip.setGravity(Gravity.CENTER_VERTICAL);
            chip.setPadding(dp(4), dp(6), dp(4), dp(6));
            chip.setBackground(rounded(selected ? color : COLOR_PANEL, dp(18)));
            if (!selected) {
                chip.setBackground(rounded(COLOR_PANEL, dp(18), color, dp(1)));
            }

            TextView label = Ui.boldText(this, tag, selected ? textColor : COLOR_TEXT, 14);
            label.setPadding(dp(12), 0, dp(4), 0);
            chip.addView(label, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

            chip.setOnClickListener(v -> {
                List<String> current = new ArrayList<>(editSession.profile.tags);
                boolean exists = false;
                for (String existing : current) {
                    if (CardTagIndex.canonicalKey(existing).equals(CardTagIndex.canonicalKey(tag))) {
                        exists = true;
                        break;
                    }
                }
                if (exists) {
                    current.removeIf(existing -> CardTagIndex.canonicalKey(existing).equals(CardTagIndex.canonicalKey(tag)));
                } else if (current.size() >= 10) {
                    toast(i18n.t("tagLimitReached"));
                } else {
                    current.add(tag);
                    recordTagUse(tag);
                }
                writeTags(current);
            });

            LinearLayout.LayoutParams chipParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            chipParams.setMargins(0, 0, 0, dp(6));
            container.addView(chip, chipParams);
        }
    }

    private void pruneTagOverrides(MeQrProfile profile) {
        profile.tagColorOverrides.keySet().removeIf(tag -> !profile.tags.contains(tag));
        profile.tagTextWeights.keySet().removeIf(tag -> !profile.tags.contains(tag));
    }

    private void updatePreview() {
        if (editSession == null) {
            return;
        }
        applyEditFields(editSession.profile);
        if (editSession.preview != null) {
            editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720, editSession.selectedQrIndex));
        }
        if (editSession.avatarPreview != null) {
            editSession.avatarPreview.setImageBitmap(renderAvatarPreview(editSession.profile));
        }
    }

    private Bitmap renderAvatarPreview(MeQrProfile profile) {
        Bitmap avatar = decodeBitmap(profile.avatarPath);
        int size = dp(96);
        if (avatar == null) {
            return initialBitmap(profile.name, size, Ui.TEAL, Color.WHITE);
        }
        return circleBitmap(avatar, size);
    }

    private void attachPreviewUpdates() {
        TextWatcher watcher = new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                updatePreview();
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        };
        editSession.name.addTextChangedListener(watcher);
        editSession.subtitle.addTextChangedListener(watcher);
        editSession.passSubtitle.addTextChangedListener(watcher);
        editSession.textColor.addTextChangedListener(watcher);
        editSession.qrColor.addTextChangedListener(watcher);
        editSession.backgroundColor.addTextChangedListener(watcher);
        editSession.borderColor.addTextChangedListener(watcher);
    }

    private void attachOnboardingAppearanceUpdates() {
        TextWatcher watcher = new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                updatePreview();
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        };
        if (editSession.passSubtitle != null) {
            editSession.passSubtitle.addTextChangedListener(watcher);
        }
        if (editSession.textColor != null) {
            editSession.textColor.addTextChangedListener(watcher);
        }
        if (editSession.qrColor != null) {
            editSession.qrColor.addTextChangedListener(watcher);
        }
        if (editSession.backgroundColor != null) {
            editSession.backgroundColor.addTextChangedListener(watcher);
        }
    }

    private void attachQRWarning(LinearLayout parent, MeQrItem item, EditText field, Button platform) {
        TextView warning = Ui.text(this, "", COLOR_MUTED, 13);
        warning.setPadding(dp(12), dp(8), dp(12), dp(8));
        Runnable refresh = () -> {
            String key = QRLinkPolicy.warningKey(field.getText().toString(), item.platform);
            String message = key == null ? "" : i18n.t(key);
            if ("qq".equals(item.platform) || "wechat".equals(item.platform)) {
                message += (message.isEmpty() ? "" : "\n") + i18n.t("qrOfficialImportHint");
            }
            warning.setText(message);
            warning.setVisibility(message.isEmpty() ? View.GONE : View.VISIBLE);
        };
        platform.setTag(refresh);
        field.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { }
            @Override public void afterTextChanged(Editable s) { refresh.run(); }
        });
        parent.addView(warning);
        refresh.run();
    }

    private void showPlatformPicker(MeQrItem item, Button platformButton, EditText customPlatformName) {
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        android.widget.HorizontalScrollView tabsScroll = new android.widget.HorizontalScrollView(this);
        android.widget.RadioGroup tabs = new android.widget.RadioGroup(this);
        tabs.setOrientation(LinearLayout.HORIZONTAL);
        String[] names = {"commonPlatforms", "socialPlatforms", "professionalPlatforms", "custom"};
        List<List<String>> groups = java.util.Arrays.asList(PlatformNames.COMMON_IDS,
                PlatformNames.SOCIAL_IDS, PlatformNames.PROFESSIONAL_IDS, java.util.Collections.singletonList("custom"));
        for (int i = 0; i < names.length; i++) {
            android.widget.RadioButton tab = new android.widget.RadioButton(this);
            tab.setId(View.generateViewId());
            tab.setButtonDrawable((android.graphics.drawable.Drawable) null);
            tab.setSingleLine(true);
            tab.setTextSize(14);
            tab.setGravity(Gravity.CENTER);
            tab.setPadding(dp(12), dp(14), dp(12), dp(14));
            tab.setTextColor(new android.content.res.ColorStateList(
                    new int[][]{new int[]{android.R.attr.state_checked}, new int[]{}},
                    new int[]{Ui.TEAL, COLOR_MUTED}));
            android.graphics.drawable.StateListDrawable background = new android.graphics.drawable.StateListDrawable();
            background.addState(new int[]{android.R.attr.state_checked}, new ColorDrawable(COLOR_PANEL_2));
            background.addState(new int[]{}, new ColorDrawable(Color.TRANSPARENT));
            tab.setBackground(background);
            tab.setText(i == 3 ? PlatformNames.displayName("custom", i18n) : i18n.t(names[i]));
            tabs.addView(tab);
        }
        tabsScroll.addView(tabs);
        content.addView(tabsScroll);
        android.widget.ListView rows = new android.widget.ListView(this);
        content.addView(rows, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(330)));
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("platform"))
                .setView(content).setNegativeButton(i18n.t("cancel"), null).create();
        tabs.setOnCheckedChangeListener((group, checked) -> {
            List<String> ids = groups.get(tabs.indexOfChild(tabs.findViewById(checked)));
            List<String> labels = new ArrayList<>();
            for (String id : ids) labels.add(PlatformNames.displayName(id, i18n));
            rows.setAdapter(new android.widget.ArrayAdapter<>(this, android.R.layout.simple_list_item_single_choice, labels));
            rows.setChoiceMode(android.widget.ListView.CHOICE_MODE_SINGLE);
            for (int i = 0; i < ids.size(); i++) {
                if (PlatformNames.actualId(ids.get(i), i18n).equals(item.platform)) rows.setItemChecked(i, true);
            }
            rows.setOnItemClickListener((parent, view, which, id) -> {
                    String selected = ids.get(which);
                    item.platform = PlatformNames.actualId(selected, i18n);
                    platformButton.setText(PlatformNames.displayName(item.platform, i18n));
                    customPlatformName.setVisibility("custom".equals(item.platform) ? View.VISIBLE : View.GONE);
                    if (platformButton.getTag() instanceof Runnable) ((Runnable) platformButton.getTag()).run();
                    updatePreview();
                    dialog.dismiss();
            });
        });
        int initialGroup = 0;
        for (int g = 0; g < groups.size(); g++) {
            for (String id : groups.get(g)) {
                if (PlatformNames.actualId(id, i18n).equals(item.platform)) { initialGroup = g; break; }
            }
        }
        tabs.check(tabs.getChildAt(initialGroup).getId());
        dialog.show();
        styleAlert(dialog);
    }

    private void rebuildQrItemsPanel() {
        if (editSession == null || editSession.qrItemsPanel == null) {
            return;
        }
        LinearLayout container = editSession.qrItemsPanel;
        container.removeAllViews();
        for (int index = 0; index < editSession.profile.qrItems.size(); index++) {
            MeQrItem item = editSession.profile.qrItems.get(index);
            LinearLayout card = panel();

            LinearLayout header = new LinearLayout(this);
            header.setOrientation(LinearLayout.HORIZONTAL);
            header.setGravity(Gravity.CENTER_VERTICAL);
            header.setPadding(dp(14), dp(8), dp(8), dp(4));
            TextView number = new TextView(this);
            number.setText(String.format(Locale.getDefault(), "%02d  %s", index + 1, item.platformDisplayName(i18n)));
            number.setTextColor(COLOR_TEXT);
            number.setTextSize(15);
            number.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
            header.addView(number, new LinearLayout.LayoutParams(0, dp(42), 1));
            if (index > 0) {
                Button up = smallButton("↑");
                int itemIndex = index;
                up.setOnClickListener(v -> moveQrItem(itemIndex, -1));
                header.addView(up, new LinearLayout.LayoutParams(dp(44), dp(40)));
            }
            if (index < editSession.profile.qrItems.size() - 1) {
                Button down = smallButton("↓");
                int itemIndex = index;
                down.setOnClickListener(v -> moveQrItem(itemIndex, 1));
                header.addView(down, new LinearLayout.LayoutParams(dp(44), dp(40)));
            }
            Button remove = smallButton("×");
            remove.setEnabled(editSession.profile.qrItems.size() > 1);
            remove.setAlpha(remove.isEnabled() ? 1f : 0.35f);
            int itemIndex = index;
            remove.setOnClickListener(v -> removeQrItem(itemIndex));
            header.addView(remove, new LinearLayout.LayoutParams(dp(44), dp(40)));
            card.addView(header);
            card.addView(separator());

            Button platform = rowButton(item.platformDisplayName(i18n), "⌄");
            EditText custom = field(i18n.t("customPlatform"), item.customPlatformName, false);
            custom.setVisibility("custom".equals(item.platform) ? View.VISIBLE : View.GONE);
            platform.setOnClickListener(v -> showPlatformPicker(item, platform, custom));
            card.addView(platform, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(54)));
            card.addView(custom);
            card.addView(separator());

            EditText qrContent = field(i18n.t("qrContent"), item.qrContent, true);
            qrContent.setMinLines(2);
            card.addView(qrContent);
            card.addView(separator());
            Button importQr = actionButton(i18n.t("importQrImage"));
            importQr.setOnClickListener(v -> {
                pendingQrItem = item;
                pendingQrField = qrContent;
                editSession.selectedQrIndex = editSession.profile.qrItems.indexOf(item);
                chooseImage(PICK_QR_IMAGE);
            });
            card.addView(importQr, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));

            TextWatcher itemWatcher = new TextWatcher() {
                @Override public void beforeTextChanged(CharSequence value, int start, int count, int after) { }
                @Override public void onTextChanged(CharSequence value, int start, int before, int count) {
                    item.qrContent = qrContent.getText().toString();
                    item.customPlatformName = custom.getText().toString();
                    updatePreview();
                }
                @Override public void afterTextChanged(Editable value) { }
            };
            qrContent.addTextChangedListener(itemWatcher);
            custom.addTextChangedListener(itemWatcher);
            attachQRWarning(card, item, qrContent, platform);
            card.setOnClickListener(v -> {
                editSession.selectedQrIndex = editSession.profile.qrItems.indexOf(item);
                updatePreview();
            });

            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            params.setMargins(0, 0, 0, dp(10));
            container.addView(card, params);
        }
    }

    private void moveQrItem(int index, int delta) {
        int target = index + delta;
        if (target < 0 || target >= editSession.profile.qrItems.size()) {
            return;
        }
        Collections.swap(editSession.profile.qrItems, index, target);
        editSession.selectedQrIndex = target;
        rebuildQrItemsPanel();
        updatePreview();
    }

    private void removeQrItem(int index) {
        if (editSession.profile.qrItems.size() <= 1) {
            return;
        }
        editSession.profile.qrItems.remove(index);
        editSession.selectedQrIndex = Math.max(0, Math.min(editSession.selectedQrIndex, editSession.profile.qrItems.size() - 1));
        rebuildQrItemsPanel();
        updatePreview();
    }

    private void addPlatformGroup(List<String> ids, List<String> labels, String title, List<String> groupIds) {
        ids.add("");
        labels.add("— " + title + " —");
        for (String id : groupIds) {
            ids.add(id);
            labels.add(PlatformNames.displayName(id, i18n));
        }
    }

    private void confirmDelete(MeQrProfile profile) {
        new AlertDialog.Builder(this)
                .setMessage(i18n.t("deleteConfirm"))
                .setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("delete"), (dialog, which) -> {
                    profiles.remove(profile);
                    persistAndRefresh();
                })
                .show();
    }

    private void moveProfile(int index, int delta) {
        int target = index + delta;
        if (target < 0 || target >= profiles.size()) {
            return;
        }
        Collections.swap(profiles, index, target);
        persistAndRefresh();
    }

    private void persistAndRefresh() {
        try {
            store.save(profiles);
        } catch (Exception exception) {
            toast(i18n.t("saveFailed"));
        } catch (OutOfMemoryError error) {
            System.gc();
            toast(i18n.t("saveFailed"));
        }
        renderMain();
    }

    private void chooseImage(int requestCode) {
        Intent intent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        intent.setDataAndType(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            startActivityForResult(intent, requestCode);
        } catch (Exception exception) {
            Intent fallback = new Intent(Intent.ACTION_GET_CONTENT);
            fallback.addCategory(Intent.CATEGORY_OPENABLE);
            fallback.setType("image/*");
            fallback.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            try {
                startActivityForResult(fallback, requestCode);
            } catch (Exception ignored) {
                toast(i18n.t("saveFailed"));
                if (requestCode == PICK_SCAN_QR) restoreScannerAfterImagePicker();
            }
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null || data.getData() == null) {
            if (requestCode == PICK_SCAN_QR) restoreScannerAfterImagePicker();
            return;
        }
        if (requestCode == PICK_SCAN_QR) choosingScanImage = false;
        Uri uri = data.getData();
        if (requestCode == PICK_EXPORT_BACKUP) {
            exportBackup(uri);
            return;
        }
        if (requestCode == PICK_IMPORT_BACKUP) {
            confirmImportBackup(uri);
            return;
        }
        try {
            Bitmap source = decodeSelectedImage(uri, requestCode);
            if (source == null) {
                toast(i18n.t("saveFailed"));
                return;
            }
            if (requestCode == PICK_SCAN_QR) {
                decodeScanImage(source);
            } else if (requestCode == PICK_QR_IMAGE && editSession != null) {
                decodeQrImage(source);
            } else if (requestCode == PICK_BANNER && editSession != null) {
                croppingBanner = true;
                showCropper(source, CropMode.BANNER);
            } else if (requestCode == PICK_BACKGROUND && editSession != null) {
                croppingBanner = false;
                showCropper(source, CropMode.BACKGROUND);
            } else if (requestCode == PICK_AVATAR && editSession != null) {
                croppingBanner = false;
                showCropper(source, CropMode.AVATAR);
            }
        } catch (IOException exception) {
            toast(i18n.t("saveFailed"));
        }
    }

    private Bitmap decodeSelectedImage(Uri uri, int requestCode) throws IOException {
        int maxDimension = requestCode == PICK_SCAN_QR || requestCode == PICK_QR_IMAGE ? 4096 : 3072;
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        try (InputStream input = getContentResolver().openInputStream(uri)) {
            BitmapFactory.decodeStream(input, null, bounds);
        }

        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null;
        }

        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = 1;
        while (Math.max(bounds.outWidth / options.inSampleSize,
                bounds.outHeight / options.inSampleSize) > maxDimension) {
            options.inSampleSize *= 2;
        }
        options.inPreferredConfig = Bitmap.Config.ARGB_8888;
        try (InputStream input = getContentResolver().openInputStream(uri)) {
            return BitmapFactory.decodeStream(input, null, options);
        }
    }

    private void exportBackup(Uri uri) {
        new Thread(() -> {
            try {
                backupManager.exportBackup(uri);
                runOnUiThread(() -> toast(i18n.t("backupDone")));
            } catch (Exception exception) {
                runOnUiThread(() -> toast(i18n.t("backupFailed")));
            }
        }).start();
    }

    private void confirmImportBackup(Uri uri) {
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("restoreData"))
                .setMessage(i18n.t("restoreConfirm"))
                .setPositiveButton(i18n.t("restore"), (d, which) -> {
                    new Thread(() -> {
                        try {
                            List<MeQrProfile> restored = backupManager.importBackup(uri);
                            runOnUiThread(() -> {
                                profiles.clear();
                                profiles.addAll(restored);
                                try {
                                    store.save(profiles);
                                } catch (IOException exception) {
                                    toast(i18n.t("saveFailed"));
                                }
                                renderMain();
                                toast(i18n.t("restoreDone"));
                            });
                        } catch (Exception exception) {
                            runOnUiThread(() -> toast(i18n.t("restoreFailed")));
                        }
                    }).start();
                })
                .setNegativeButton(i18n.t("cancel"), null)
                .show();
        styleAlert(dialog);
    }

    private void decodeScanImage(Bitmap bitmap) {
        scanningPhoto = true;
        try {
            decodeQrImage(bitmap);
        } finally {
            scanningPhoto = false;
        }
    }

    private void restoreScannerAfterImagePicker() {
        if (!choosingScanImage) return;
        choosingScanImage = false;
        showScan();
    }

    private void showCropper(Bitmap source, CropMode mode) {
        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(Color.BLACK);

        LinearLayout topBar = new LinearLayout(this);
        topBar.setGravity(Gravity.CENTER_VERTICAL);
        topBar.setPadding(dp(18), statusTop() + dp(10), dp(18), dp(8));
        topBar.setOrientation(LinearLayout.HORIZONTAL);

        Button cancel = iconButton("×");
        cancel.setTextSize(28);
        cancel.setOnClickListener(v -> dialog.dismiss());
        topBar.addView(cancel, new LinearLayout.LayoutParams(dp(54), dp(48)));

        TextView title = new TextView(this);
        title.setText(mode == CropMode.AVATAR ? i18n.t("avatar")
                : mode == CropMode.BANNER ? i18n.t("bannerImage") : i18n.t("backgroundImage"));
        title.setTextColor(Color.WHITE);
        title.setTextSize(22);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setPadding(dp(14), 0, 0, 0);
        topBar.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        CropImageView cropView = new CropImageView(this, source, mode);
        Button save = filledButton(i18n.t("save"));
        save.setOnClickListener(v -> {
            try {
                Bitmap cropped = cropView.crop();
                if (mode == CropMode.AVATAR) {
                    editSession.profile.avatarPath = store.saveBitmap(cropped, "avatar");
                } else if (mode == CropMode.BANNER) {
                    editSession.profile.bannerPath = store.saveBitmap(cropped, "banner");
                } else {
                    editSession.profile.backgroundPath = store.saveBitmap(cropped, "background");
                }
                updatePreview();
                croppingBanner = false;
                toast(i18n.t("done"));
                dialog.dismiss();
            } catch (IOException exception) {
                toast(i18n.t("saveFailed"));
            }
        });
        topBar.addView(save, new LinearLayout.LayoutParams(dp(96), dp(48)));
        page.addView(topBar);

        page.addView(cropView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        dialog.setContentView(page);
        dialog.show();
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(Color.BLACK));
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        }
    }

    private void decodeQrImage(Bitmap bitmap) {
        try {
            Result result = QrImageDecoder.decode(bitmap);
            if (scanningPhoto) {
                handleMeQrPayload(result.getText(), MeQrColorLayer.decode(bitmap, result));
                return;
            }
            if (pendingQrItem != null) {
                pendingQrItem.qrContent = result.getText();
                String detected = PlatformNames.detect(result.getText());
                if (!"custom".equals(detected)) {
                    pendingQrItem.platform = detected;
                    pendingQrItem.customPlatformName = "";
                }
            }
            if (pendingQrField != null) {
                pendingQrField.setText(result.getText());
            }
            rebuildQrItemsPanel();
            updatePreview();
            toast(i18n.t("done"));
        } catch (Exception exception) {
            toast(i18n.t("qrDecodeFailed"));
        } finally {
            pendingQrItem = null;
            pendingQrField = null;
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_CAMERA) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                openScanner();
            } else {
                toast(i18n.t("cameraPermissionNeeded"));
            }
        } else if (requestCode == REQUEST_WRITE_PHOTOS && pendingMeQrBitmap != null) {
            Bitmap bitmap = pendingMeQrBitmap;
            pendingMeQrBitmap = null;
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                saveMeQrBitmap(bitmap);
            }
        }
    }

    private Uri saveBitmapToGallery(Bitmap bitmap) {
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, "MeQR_" + System.currentTimeMillis() + ".png");
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        if (Build.VERSION.SDK_INT >= 29) {
            values.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/MeQR");
            values.put(MediaStore.Images.Media.IS_PENDING, 1);
        }
        Uri uri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) {
            return null;
        }
        try (OutputStream output = getContentResolver().openOutputStream(uri)) {
            if (output == null) {
                return null;
            }
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output);
        } catch (IOException exception) {
            return null;
        }
        if (Build.VERSION.SDK_INT >= 29) {
            values.clear();
            values.put(MediaStore.Images.Media.IS_PENDING, 0);
            getContentResolver().update(uri, values, null, null);
        }
        return uri;
    }

    // Top-right MeQR menu, acts on the current card.
    private void showShareMenu(MeQrProfile profile) {
        List<ActionSheetItem> actions = new ArrayList<>();
        actions.add(new ActionSheetItem("QR", i18n.t("meqrProfileCode"), false, () -> showMeQrCode(profile)));
        actions.add(new ActionSheetItem("◎", i18n.t("encounters"), false, this::showEncounters));
        actions.add(new ActionSheetItem("▤", i18n.t("events"), false, this::showEventCenter));
        showActionSheet(cardTitle(profile), actions);
    }

    // Leading menu acts on the current card.
    private void showCardMenu(MeQrProfile profile, int index) {
        List<ActionSheetItem> actions = new ArrayList<>();
        actions.add(new ActionSheetItem("list", i18n.t("cardList"), false, () -> {
            showingCardList = true;
            renderMain();
        }));
        actions.add(new ActionSheetItem("✎", i18n.t("edit"), false, () -> showEditor(profile)));
        if (profiles.size() > 1) {
            if (index > 0) {
                actions.add(new ActionSheetItem("↑", i18n.t("moveUp"), false, () -> {
                    currentPage = index - 1;
                    moveProfile(index, -1);
                }));
            }
            if (index < profiles.size() - 1) {
                actions.add(new ActionSheetItem("↓", i18n.t("moveDown"), false, () -> {
                    currentPage = index + 1;
                    moveProfile(index, 1);
                }));
            }
        }
        actions.add(new ActionSheetItem("×", i18n.t("delete"), true, () -> confirmDelete(profile)));
        actions.add(new ActionSheetItem("⚙", i18n.t("settings"), false, this::showSettings));
        showActionSheet(cardTitle(profile), actions);
    }

    private String eventDisplayTitle(MeQrEvent event) {
        return MeQrEvent.DEFAULT_EVENT_ID.equals(event.id) ? i18n.t("defaultEventTitle") : event.title;
    }

    private String eventDisplayVenue(MeQrEvent event) {
        return MeQrEvent.DEFAULT_EVENT_ID.equals(event.id) ? i18n.t("defaultEventVenue") : event.venue;
    }

    private void addCappedScrollView(LinearLayout parent, ScrollView scroll, double maxScreenFraction) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        parent.addView(scroll, params);
        int maxHeight = (int) (getResources().getDisplayMetrics().heightPixels * maxScreenFraction);
        scroll.getViewTreeObserver().addOnGlobalLayoutListener(() -> {
            if (scroll.getHeight() > maxHeight) {
                params.height = maxHeight;
                scroll.setLayoutParams(params);
            }
        });
    }

    private void showActionSheet(String titleText, List<ActionSheetItem> actions) {
        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCanceledOnTouchOutside(true);

        LinearLayout sheet = new LinearLayout(this);
        sheet.setOrientation(LinearLayout.VERTICAL);
        sheet.setPadding(dp(16), dp(10), dp(16), Math.max(dp(18), navigationBottom() + dp(8)));
        sheet.setBackground(topRounded(COLOR_SURFACE, dp(20)));

        View handle = new View(this);
        handle.setBackground(rounded(Color.rgb(78, 89, 104), dp(2)));
        LinearLayout.LayoutParams handleParams = new LinearLayout.LayoutParams(dp(38), dp(4));
        handleParams.gravity = Gravity.CENTER_HORIZONTAL;
        handleParams.setMargins(0, 0, 0, dp(12));
        sheet.addView(handle, handleParams);

        TextView title = new TextView(this);
        title.setText(titleText == null || titleText.trim().isEmpty() ? i18n.t("appName") : titleText);
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(18);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setIncludeFontPadding(false);
        title.setPadding(dp(6), dp(2), dp(6), dp(12));
        sheet.addView(title);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        scroll.setOverScrollMode(View.OVER_SCROLL_IF_CONTENT_SCROLLS);
        LinearLayout rows = new LinearLayout(this);
        rows.setOrientation(LinearLayout.VERTICAL);
        rows.setBackground(rounded(COLOR_PANEL, dp(14), COLOR_SEPARATOR, dp(1)));
        for (int index = 0; index < actions.size(); index++) {
            ActionSheetItem item = actions.get(index);
            LinearLayout row = actionSheetRow(item, dialog);
            rows.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(58)));
            if (index < actions.size() - 1) {
                rows.addView(separator());
            }
        }
        scroll.addView(rows, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        int screenHeight = getResources().getDisplayMetrics().heightPixels;
        int reservedHeight = statusTop() + navigationBottom() + dp(156);
        int maximumRowsHeight = Math.min(dp(530), Math.max(dp(174), screenHeight - reservedHeight));
        int desiredRowsHeight = actions.size() * dp(58) + Math.max(0, actions.size() - 1) * dp(9);
        sheet.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, Math.min(desiredRowsHeight, maximumRowsHeight)));

        Button cancel = quietButton(i18n.t("cancel"));
        cancel.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        cancel.setOnClickListener(v -> dialog.dismiss());
        LinearLayout.LayoutParams cancelParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46));
        cancelParams.setMargins(0, dp(10), 0, 0);
        sheet.addView(cancel, cancelParams);

        dialog.setContentView(sheet);
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.gravity = Gravity.BOTTOM;
            attributes.width = ViewGroup.LayoutParams.MATCH_PARENT;
            attributes.height = ViewGroup.LayoutParams.WRAP_CONTENT;
            attributes.dimAmount = 0.58f;
            window.setAttributes(attributes);
        }
        dialog.show();
        if (window != null) {
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        }
    }

    private LinearLayout actionSheetRow(ActionSheetItem item, Dialog dialog) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), 0, dp(12), 0);
        row.setMinimumHeight(dp(58));
        row.setClickable(true);
        row.setFocusable(true);
        row.setOnClickListener(v -> {
            dialog.dismiss();
            item.action.run();
        });

        int textColor = item.destructive ? Color.rgb(255, 116, 116) : COLOR_TEXT;
        ImageView icon = UiIcons.view(this, item.icon, item.destructive ? Color.rgb(255, 116, 116) : Ui.SKY);
        icon.setBackground(rounded(item.destructive ? Color.argb(30, 255, 116, 116) : Color.argb(30, 161, 209, 234), dp(10)));
        row.addView(icon, new LinearLayout.LayoutParams(dp(36), dp(36)));

        TextView label = new TextView(this);
        label.setText(item.label);
        label.setTextColor(textColor);
        label.setTextSize(16);
        label.setSingleLine(true);
        label.setEllipsize(android.text.TextUtils.TruncateAt.END);
        label.setIncludeFontPadding(false);
        label.setPadding(dp(14), 0, 0, 0);
        row.addView(label, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        ImageView trailing = UiIcons.view(this, "›", COLOR_MUTED);
        row.addView(trailing, new LinearLayout.LayoutParams(dp(24), dp(36)));
        return row;
    }

    private void showSettings() {
        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackground(Ui.gradient(Ui.BG_TOP, Ui.BG, 0));

        LinearLayout topBar = new LinearLayout(this);
        topBar.setOrientation(LinearLayout.HORIZONTAL);
        topBar.setGravity(Gravity.CENTER_VERTICAL);
        topBar.setPadding(dp(20), statusTop() + dp(12), dp(18), dp(12));

        ImageView badge = UiIcons.view(this, "⚙", Ui.TEAL);
        badge.setBackground(rounded(Color.argb(38, 57, 197, 187), dp(14)));
        topBar.addView(badge, new LinearLayout.LayoutParams(dp(46), dp(46)));

        LinearLayout titleBlock = new LinearLayout(this);
        titleBlock.setOrientation(LinearLayout.VERTICAL);
        titleBlock.setPadding(dp(14), 0, 0, 0);
        TextView title = Ui.boldText(this, i18n.t("settings"), COLOR_TEXT, 22);
        title.setIncludeFontPadding(false);
        titleBlock.addView(title);
        TextView subtitle = Ui.text(this, i18n.t("appName") + " · " + i18n.t("version") + " " + appVersionName(), COLOR_MUTED, 12);
        subtitle.setIncludeFontPadding(false);
        subtitle.setPadding(0, dp(3), 0, 0);
        titleBlock.addView(subtitle);
        topBar.addView(titleBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        Button close = iconButton("×");
        close.setContentDescription(i18n.t("done"));
        close.setOnClickListener(v -> dialog.dismiss());
        topBar.addView(close, new LinearLayout.LayoutParams(dp(44), dp(44)));
        page.addView(topBar);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(18), dp(4), dp(18), Math.max(dp(40), navigationBottom() + dp(28)));

        content.addView(settingsSectionHeader(i18n.t("settingsActions")));
        LinearLayout actions = settingsGroup();
        actions.addView(settingsRow(dialog, "▦", i18n.t("scanMeQr"), i18n.t("scanMeQrHint"), this::showScan));
        actions.addView(separator());
        actions.addView(settingsRow(dialog, "◎", i18n.t("encounters"), null, this::showEncounters));
        content.addView(actions);

        content.addView(settingsSectionHeader(i18n.t("settingsGeneral")));
        LinearLayout general = settingsGroup();
        general.addView(settingsRow(dialog, "文", i18n.t("language"),
                i18n.languageDisplayName(i18n.languageMode()), this::showLanguagePicker));
        general.addView(separator());
        general.addView(settingsRow(dialog, "↻", i18n.t("checkUpdates"), null, () -> updateManager.checkManually()));
        general.addView(separator());
        general.addView(settingsRow(dialog, "01", i18n.t("replaySetup"), null, this::showOnboarding));
        general.addView(separator());
        general.addView(settingsRow(dialog, "i", i18n.t("about"), null, this::showAbout));
        content.addView(general);

        content.addView(settingsSectionHeader(i18n.t("settingsData")));
        LinearLayout data = settingsGroup();
        data.addView(settingsRow(dialog, "↓", i18n.t("backupData"), null, () -> {
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("application/zip");
            intent.putExtra(Intent.EXTRA_TITLE, "MeQR-Backup-" + new java.text.SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(new java.util.Date()) + ".zip");
            startActivityForResult(intent, PICK_EXPORT_BACKUP);
        }));
        data.addView(separator());
        data.addView(settingsRow(dialog, "↑", i18n.t("restoreData"), null, () -> {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("application/zip");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivityForResult(intent, PICK_IMPORT_BACKUP);
        }));
        content.addView(data);

        scroll.addView(content);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        dialog.setContentView(page);
        dialog.show();
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        }
    }

    private TextView settingsSectionHeader(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(13);
        view.setTextColor(Color.rgb(140, 205, 224));
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setLetterSpacing(0.05f);
        view.setPadding(dp(8), dp(26), 0, dp(10));
        return view;
    }

    private LinearLayout settingsGroup() {
        LinearLayout group = new LinearLayout(this);
        group.setOrientation(LinearLayout.VERTICAL);
        group.setPadding(dp(6), dp(6), dp(6), dp(6));
        group.setBackground(rounded(COLOR_PANEL, dp(18), Ui.BORDER, dp(1)));
        return group;
    }

    private View settingsRow(Dialog dialog, String iconText, String labelText, Runnable action) {
        return settingsRow(dialog, iconText, labelText, null, action);
    }

    private View settingsRow(Dialog dialog, String iconText, String labelText, String subtitleText, Runnable action) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), dp(4), dp(10), dp(4));
        row.setMinimumHeight(dp(64));
        row.setClickable(true);
        row.setFocusable(true);

        ImageView icon = UiIcons.view(this, iconText, Ui.SKY);
        icon.setBackground(rounded(Color.argb(30, 161, 209, 234), dp(12)));
        row.addView(icon, new LinearLayout.LayoutParams(dp(40), dp(40)));

        LinearLayout textBlock = new LinearLayout(this);
        textBlock.setOrientation(LinearLayout.VERTICAL);
        textBlock.setGravity(Gravity.CENTER_VERTICAL);
        textBlock.setPadding(dp(14), 0, dp(8), 0);
        TextView label = Ui.text(this, labelText, COLOR_TEXT, 16);
        label.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        textBlock.addView(label);
        if (subtitleText != null && !subtitleText.trim().isEmpty()) {
            TextView subtitle = Ui.text(this, subtitleText, COLOR_MUTED, 12);
            subtitle.setPadding(0, dp(3), 0, 0);
            textBlock.addView(subtitle);
        }
        row.addView(textBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        ImageView trailing = UiIcons.view(this, "›", COLOR_MUTED);
        row.addView(trailing, new LinearLayout.LayoutParams(dp(24), dp(44)));
        row.setOnClickListener(v -> {
            dialog.dismiss();
            action.run();
        });
        return row;
    }

    private void showOnboarding() {
        MeQrProfile draft = new MeQrProfile();
        draft.name = "";
        draft.backgroundColor = "#F4FBFA";
        draft.borderColor = "#39C5BB";
        draft.textColor = "#183752";
        draft.qrColor = "#183752";
        int restoredStep = 0;
        String savedDraft = getSharedPreferences("settings", MODE_PRIVATE).getString("onboardingDraft", "");
        if (!savedDraft.isEmpty()) {
            try {
                org.json.JSONObject saved = new org.json.JSONObject(savedDraft);
                draft = MeQrProfile.fromJson(saved.getJSONObject("profile"));
                restoredStep = Math.max(0, Math.min(5, saved.optInt("step")));
            } catch (org.json.JSONException ignored) { }
        }
        editSession = new EditSession(draft);
        editSession.onboarding = true;
        if (!savedDraft.isEmpty()) {
            try { editSession.tagDraft = new org.json.JSONObject(savedDraft).optString("tagDraft", ""); }
            catch (org.json.JSONException ignored) { }
        }

        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackground(Ui.gradient(Color.rgb(20, 25, 31), COLOR_BG, 0));
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        page.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        renderOnboardingStep(dialog, content, restoredStep);
        handleDialogBack(dialog, () -> {
            if (onboardingStep > 0 && onboardingStep <= 5) {
                syncOnboardingFields();
                renderOnboardingStep(dialog, content, onboardingStep - 1);
            } else if (onboardingStep >= 6) {
                showingCardList = false;
                dialog.dismiss();
                renderMain();
            } else {
                confirmDiscard(() -> {
                    getSharedPreferences("settings", MODE_PRIVATE).edit().remove("onboardingDraft").apply();
                    dialog.dismiss();
                });
            }
        });
        dialog.setContentView(page);
        dialog.setOnDismissListener(ignored -> {
            editingProfile = null;
            editSession = null;
        });
        dialog.show();
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(COLOR_BG));
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        }
    }

    private void renderOnboardingStep(Dialog dialog, LinearLayout content, int step) {
        if (editSession.tags != null && editSession.onboarding) {
            editSession.tagDraft = editSession.tags.getText().toString();
        }
        onboardingStep = step;
        saveOnboardingDraft();
        content.removeAllViews();
        if (step == 0) {
            renderOnboardingWelcome(dialog, content);
            return;
        }
        if (step == 6) {
            renderOnboardingComplete(dialog, content);
            return;
        }
        if (step == 7) {
            renderOnboardingSupport(dialog, content);
            return;
        }

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.VERTICAL);
        top.setPadding(dp(24), statusTop() + dp(14), dp(24), dp(14));
        top.setBackgroundColor(Color.argb(238, 20, 21, 24));
        LinearLayout meta = new LinearLayout(this);
        meta.setOrientation(LinearLayout.HORIZONTAL);
        meta.setGravity(Gravity.CENTER_VERTICAL);
        TextView mark = onboardingMark();
        meta.addView(mark, new LinearLayout.LayoutParams(dp(42), dp(42)));
        View metaSpacer = new View(this);
        meta.addView(metaSpacer, new LinearLayout.LayoutParams(0, dp(1), 1));
        TextView count = new TextView(this);
        count.setText(step + " / 5");
        count.setTextColor(COLOR_MUTED);
        count.setTextSize(13);
        count.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        count.setTypeface(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD);
        count.setContentDescription(i18n.t("setupProgress"));
        meta.addView(count, new LinearLayout.LayoutParams(dp(64), dp(42)));
        top.addView(meta);
        LinearLayout progress = new LinearLayout(this);
        progress.setOrientation(LinearLayout.HORIZONTAL);
        progress.setPadding(0, dp(8), 0, 0);
        for (int i = 1; i <= 5; i++) {
            View segment = new View(this);
            segment.setBackground(rounded(i <= step ? Ui.TEAL : Color.rgb(52, 54, 59), dp(3)));
            LinearLayout.LayoutParams segmentParams = new LinearLayout.LayoutParams(0, dp(6), i == step ? 1.55f : 1f);
            segmentParams.setMargins(0, 0, i == 5 ? 0 : dp(7), 0);
            progress.addView(segment, segmentParams);
        }
        top.addView(progress);
        content.addView(top);

        ScrollView scroll = new ScrollView(this);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setPadding(dp(26), dp(28), dp(26), dp(132));
        scroll.addView(body);
        content.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        String[] titles = {"setupWelcome", "setupIdentity", "setupQr", "setupAppearance", "setupTags", "setupFinal"};
        String[] bodies = {"setupWelcomeBody", "setupIdentityBody", "setupQrBody", "setupAppearanceBody", "setupTagsBody", "setupFinalBody"};
        body.addView(onboardingStepTitle(String.format(Locale.US, "%02d", step), i18n.t(titles[step]), i18n.t(bodies[step])));

        if (step == 1) {
            LinearLayout avatarRow = new LinearLayout(this);
            avatarRow.setOrientation(LinearLayout.HORIZONTAL);
            avatarRow.setGravity(Gravity.CENTER_VERTICAL);
            avatarRow.setPadding(dp(4), 0, dp(4), dp(12));
            editSession.avatarPreview = new ImageView(this);
            editSession.avatarPreview.setScaleType(ImageView.ScaleType.FIT_CENTER);
            editSession.avatarPreview.setImageBitmap(renderAvatarPreview(editSession.profile));
            avatarRow.addView(editSession.avatarPreview, new LinearLayout.LayoutParams(dp(96), dp(96)));
            Button avatar = actionButton(editSession.profile.avatarPath.isEmpty()
                    ? i18n.t("chooseImage") + " · " + i18n.t("avatar")
                    : i18n.t("chooseImage") + " · " + i18n.t("avatar"));
            avatar.setOnClickListener(v -> {
                syncOnboardingFields();
                chooseImage(PICK_AVATAR);
            });
            LinearLayout.LayoutParams avatarParams = new LinearLayout.LayoutParams(0, dp(52), 1);
            avatarParams.setMargins(dp(16), 0, 0, 0);
            avatarRow.addView(avatar, avatarParams);
            body.addView(avatarRow);

            LinearLayout identity = panel();
            editSession.name = field(i18n.t("profileName"), editSession.profile.name, false);
            editSession.subtitle = field(i18n.t("bio"), editSession.profile.subtitle, true);
            identity.addView(editSession.name);
            identity.addView(separator());
            identity.addView(editSession.subtitle);
            body.addView(identity);
        } else if (step == 2) {
            MeQrItem item = editSession.profile.firstItem();
            LinearLayout qrPanel = panel();
            Button platform = rowButton(item.platformDisplayName(i18n), "⌄");
            EditText custom = field(i18n.t("customPlatform"), item.customPlatformName, false);
            custom.setVisibility("custom".equals(item.platform) ? View.VISIBLE : View.GONE);
            platform.setOnClickListener(v -> showPlatformPicker(item, platform, custom));
            EditText qr = field(i18n.t("qrContent"), item.qrContent, true);
            qrPanel.addView(platform, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(54)));
            qrPanel.addView(custom);
            qrPanel.addView(separator());
            qrPanel.addView(qr);
            body.addView(qrPanel);
            attachQRWarning(qrPanel, item, qr, platform);
            TextWatcher watcher = directItemWatcher(item, qr, custom);
            qr.addTextChangedListener(watcher);
            custom.addTextChangedListener(watcher);
            qr.addTextChangedListener(new TextWatcher() {
                @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
                @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                    String detected = PlatformNames.detect(s.toString());
                    if ("custom".equals(detected)) {
                        return;
                    }
                    if (PlatformNames.actualId(detected, i18n).equals(item.platform)) {
                        return;
                    }
                    item.platform = PlatformNames.actualId(detected, i18n);
                    item.customPlatformName = "";
                    platform.setText(item.platformDisplayName(i18n));
                    custom.setVisibility("custom".equals(item.platform) ? View.VISIBLE : View.GONE);
                    updatePreview();
                }
                @Override public void afterTextChanged(Editable s) { }
            });
            Button importQr = actionButton(i18n.t("importQrImage"));
            importQr.setOnClickListener(v -> {
                pendingQrItem = item;
                pendingQrField = qr;
                chooseImage(PICK_QR_IMAGE);
            });
            LinearLayout.LayoutParams importParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
            importParams.setMargins(0, dp(10), 0, 0);
            body.addView(importQr, importParams);
        } else if (step == 3) {
            editSession.preview = new ImageView(this);
            editSession.preview.setAdjustViewBounds(true);
            editSession.preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
            editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720, editSession.selectedQrIndex));
            LinearLayout previewPanel = panel();
            previewPanel.setGravity(Gravity.CENTER);
            previewPanel.addView(editSession.preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(320)));
            body.addView(previewPanel);

            LinearLayout templates = panel();
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setBaselineAligned(false);
            row.setPadding(dp(6), dp(6), dp(6), dp(6));
            Button standard = templateButton(i18n.t("standardTemplate"), "standard".equals(editSession.profile.template));
            Button rhodes = templateButton(i18n.t("rhodesTemplate"), "rhodes".equals(editSession.profile.template));
            editSession.passSubtitle = field(i18n.t("passSubtitleLabel"), editSession.profile.passSubtitle, false);
            TextView passHint = Ui.text(this, i18n.t("passSubtitleHint"), COLOR_MUTED, 12);
            passHint.setPadding(dp(4), dp(6), dp(4), 0);
            boolean rhodesSelected = "rhodes".equals(editSession.profile.template);
            editSession.passSubtitle.setVisibility(rhodesSelected ? View.VISIBLE : View.GONE);
            passHint.setVisibility(rhodesSelected ? View.VISIBLE : View.GONE);
            Button banner = actionButton(i18n.t("bannerImage") + " · " + i18n.t("chooseImage"));
            standard.setOnClickListener(v -> {
                editSession.profile.template = "standard";
                styleTemplateButtons(standard, rhodes);
                editSession.passSubtitle.setVisibility(View.GONE);
                passHint.setVisibility(View.GONE);
                banner.setVisibility(View.GONE);
                updatePreview();
            });
            rhodes.setOnClickListener(v -> {
                editSession.profile.template = "rhodes";
                styleTemplateButtons(rhodes, standard);
                editSession.passSubtitle.setVisibility(View.VISIBLE);
                passHint.setVisibility(View.VISIBLE);
                banner.setVisibility(View.VISIBLE);
                updatePreview();
            });
            standard.setMinimumHeight(dp(48));
            rhodes.setMinimumHeight(dp(48));
            row.addView(standard, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            LinearLayout.LayoutParams rhodesParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            rhodesParams.setMargins(dp(6), 0, 0, 0);
            row.addView(rhodes, rhodesParams);
            templates.addView(row);
            templates.addView(editSession.passSubtitle);
            templates.addView(passHint);
            body.addView(templates);
            LinearLayout colors = panel();
            editSession.textColor = addColorRow(colors, i18n.t("textColor"), editSession.profile.textColor);
            colors.addView(separator());
            editSession.qrColor = addColorRow(colors, i18n.t("qrColor"), editSession.profile.qrColor);
            colors.addView(separator());
            editSession.backgroundColor = addColorRow(colors, i18n.t("backgroundColor"), editSession.profile.backgroundColor);
            body.addView(colors);
            attachOnboardingAppearanceUpdates();
            Button background = actionButton(i18n.t("chooseImage") + " · " + i18n.t("backgroundImage"));
            background.setOnClickListener(v -> {
                syncOnboardingFields();
                chooseImage(PICK_BACKGROUND);
            });
            LinearLayout.LayoutParams backgroundParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
            backgroundParams.setMargins(0, dp(10), 0, 0);
            body.addView(background, backgroundParams);
            banner.setVisibility(rhodesSelected ? View.VISIBLE : View.GONE);
            banner.setOnClickListener(v -> {
                syncOnboardingFields();
                chooseImage(PICK_BANNER);
            });
            LinearLayout.LayoutParams bannerParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
            bannerParams.setMargins(0, dp(10), 0, 0);
            body.addView(banner, bannerParams);
        } else if (step == 4) {
            final LinearLayout suggestionsContainer = new LinearLayout(this);
            suggestionsContainer.setOrientation(LinearLayout.VERTICAL);
            body.addView(createTagInput(() -> rebuildOnboardingSuggestions(suggestionsContainer, editSession.tagChips)));
            LinearLayout chipsContainer = editSession.tagChips;

            TextView suggestionsLabel = Ui.text(this, i18n.t("tagSuggestions"), COLOR_MUTED, 13);
            suggestionsLabel.setPadding(dp(4), dp(18), dp(4), dp(8));
            body.addView(suggestionsLabel);
            body.addView(suggestionsContainer);
            rebuildOnboardingSuggestions(suggestionsContainer, chipsContainer);

            rebuildSelectedTagChips(chipsContainer);
        } else {
            editSession.preview = new ImageView(this);
            editSession.preview.setAdjustViewBounds(true);
            editSession.preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
            editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 900));
            LinearLayout previewPanel = panel();
            previewPanel.setGravity(Gravity.CENTER);
            previewPanel.addView(editSession.preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(340)));
            body.addView(previewPanel);

            LinearLayout summary = panel();
            MeQrItem item = editSession.profile.firstItem();
            addSummaryRow(summary, editSession.profile.name,
                    editSession.profile.subtitle.trim().isEmpty() ? i18n.t("bio") : editSession.profile.subtitle);
            summary.addView(separator());
            addSummaryRow(summary, item.platformDisplayName(i18n), i18n.t("qrContent"));
            if (!editSession.profile.tags.isEmpty()) {
                summary.addView(separator());
                addSummaryRow(summary, joinTagsInline(editSession.profile.tags), i18n.t("tags"));
            }
            body.addView(summary);
        }

        LinearLayout navigation = new LinearLayout(this);
        navigation.setOrientation(LinearLayout.HORIZONTAL);
        navigation.setGravity(Gravity.CENTER_VERTICAL);
        navigation.setPadding(dp(24), dp(12), dp(24), dp(14) + navigationBottom());
        navigation.setBackgroundColor(Color.argb(244, 20, 21, 24));
        Button back = quietButton("‹");
        back.setTextSize(28);
        back.setContentDescription(i18n.t("back"));
        back.setOnClickListener(v -> {
            syncOnboardingFields();
            renderOnboardingStep(dialog, content, step - 1);
        });
        navigation.addView(back, new LinearLayout.LayoutParams(dp(54), dp(52)));
        Button next = filledButton(step == 5 ? i18n.t("finishSetup") : i18n.t("continue"));
        next.setOnClickListener(v -> {
            if (step == 4 && !commitTagDraft()) return;
            syncOnboardingFields();
            if (step == 1 && editSession.profile.name.trim().isEmpty()) {
                toast(i18n.t("nameRequired"));
                return;
            }
            if (step == 5) {
                if (saveOnboardingProfile()) {
                    renderOnboardingStep(dialog, content, 6);
                }
            } else {
                renderOnboardingStep(dialog, content, step + 1);
            }
        });
        LinearLayout.LayoutParams nextParams = new LinearLayout.LayoutParams(0, dp(52), 1);
        nextParams.setMargins(dp(12), 0, 0, 0);
        navigation.addView(next, nextParams);
        content.addView(navigation);
    }

    private void renderOnboardingWelcome(Dialog dialog, LinearLayout content) {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setPadding(dp(28), statusTop() + dp(22), dp(28), dp(30) + navigationBottom());
        scroll.addView(body);
        content.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.addView(onboardingMark(), new LinearLayout.LayoutParams(dp(44), dp(44)));
        View headerSpacer = new View(this);
        header.addView(headerSpacer, new LinearLayout.LayoutParams(0, dp(1), 1));
        TextView eyebrow = new TextView(this);
        eyebrow.setText(i18n.t("setupEyebrow"));
        eyebrow.setTextColor(COLOR_MUTED);
        eyebrow.setTextSize(10);
        eyebrow.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        eyebrow.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        header.addView(eyebrow);
        Button language = lightIconButton("文");
        language.setContentDescription(i18n.t("language"));
        language.setOnClickListener(v -> showLanguagePicker(() -> renderOnboardingStep(dialog, content, 0)));
        LinearLayout.LayoutParams languageParams = new LinearLayout.LayoutParams(dp(40), dp(40));
        languageParams.setMargins(dp(10), 0, 0, 0);
        header.addView(language, languageParams);
        body.addView(header);

        FrameLayout cardStack = new FrameLayout(this);
        cardStack.setPadding(dp(12), dp(24), dp(12), dp(16));
        View tealLayer = new View(this);
        tealLayer.setBackground(rounded(Color.argb(145, 57, 197, 187), dp(28)));
        tealLayer.setRotation(-4f);
        FrameLayout.LayoutParams tealParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(238), Gravity.CENTER);
        tealParams.setMargins(dp(8), dp(18), dp(8), 0);
        cardStack.addView(tealLayer, tealParams);
        View pinkLayer = new View(this);
        pinkLayer.setBackground(rounded(Color.argb(95, 255, 77, 141), dp(28)));
        pinkLayer.setRotation(4f);
        FrameLayout.LayoutParams pinkParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(238), Gravity.CENTER);
        pinkParams.setMargins(dp(8), dp(18), dp(8), 0);
        cardStack.addView(pinkLayer, pinkParams);
        ImageView sample = new ImageView(this);
        sample.setScaleType(ImageView.ScaleType.FIT_CENTER);
        MeQrProfile sampleProfile = copy(editSession.profile);
        sampleProfile.name = "Miku39";
        sampleProfile.subtitle = "QR PROFILE · 2026";
        sample.setImageBitmap(CardRenderer.render(sampleProfile, i18n, 720));
        sample.setElevation(dp(12));
        FrameLayout.LayoutParams sampleParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(260), Gravity.CENTER);
        sampleParams.setMargins(dp(18), dp(8), dp(18), 0);
        cardStack.addView(sample, sampleParams);
        LinearLayout.LayoutParams stackParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(310));
        stackParams.setMargins(0, dp(40), 0, 0);
        body.addView(cardStack, stackParams);

        TextView title = new TextView(this);
        title.setText(i18n.t("setupWelcome"));
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(36);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setLineSpacing(dp(3), 1f);
        title.setPadding(0, dp(30), 0, 0);
        body.addView(title);
        TextView intro = new TextView(this);
        intro.setText(i18n.t("setupWelcomeBody"));
        intro.setTextColor(COLOR_MUTED);
        intro.setTextSize(16);
        intro.setLineSpacing(dp(5), 1f);
        intro.setPadding(0, dp(14), 0, dp(26));
        body.addView(intro);
        Button start = filledButton(i18n.t("setupStart"));
        start.setOnClickListener(v -> renderOnboardingStep(dialog, content, 1));
        body.addView(start, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
        Button later = quietButton(i18n.t("cancel"));
        later.setOnClickListener(v -> confirmDiscard(() -> {
            getSharedPreferences("settings", MODE_PRIVATE).edit().remove("onboardingDraft").apply();
            dialog.dismiss();
        }));
        LinearLayout.LayoutParams laterParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        laterParams.setMargins(0, dp(8), 0, 0);
        body.addView(later, laterParams);
    }

    private void renderOnboardingComplete(Dialog dialog, LinearLayout content) {
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setGravity(Gravity.CENTER_HORIZONTAL);
        body.setPadding(dp(28), statusTop() + dp(46), dp(28), dp(28) + navigationBottom());
        content.addView(body, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        TextView mark = onboardingMark();
        mark.setGravity(Gravity.CENTER);
        body.addView(mark, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        ImageView preview = new ImageView(this);
        preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
        preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 900));
        preview.setElevation(dp(14));
        LinearLayout.LayoutParams previewParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1);
        previewParams.setMargins(0, dp(28), 0, dp(22));
        body.addView(preview, previewParams);
        TextView title = new TextView(this);
        title.setText(i18n.t("setupComplete"));
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(32);
        title.setGravity(Gravity.CENTER);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        body.addView(title);
        TextView copy = new TextView(this);
        copy.setText(i18n.t("setupCompleteBody"));
        copy.setTextColor(COLOR_MUTED);
        copy.setTextSize(16);
        copy.setGravity(Gravity.CENTER);
        copy.setLineSpacing(dp(4), 1f);
        copy.setPadding(dp(10), dp(12), dp(10), dp(24));
        body.addView(copy);
        Button enter = filledButton(i18n.t("setupEnter"));
        enter.setOnClickListener(v -> renderOnboardingStep(dialog, content, 7));
        body.addView(enter, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
    }

    private void renderOnboardingSupport(Dialog dialog, LinearLayout content) {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setGravity(Gravity.CENTER_HORIZONTAL);
        body.setPadding(dp(28), statusTop() + dp(48), dp(28), dp(28) + navigationBottom());
        scroll.addView(body);
        content.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        TextView mark = onboardingMark();
        mark.setText("?");
        mark.setGravity(Gravity.CENTER);
        body.addView(mark, new LinearLayout.LayoutParams(dp(56), dp(56)));

        TextView title = Ui.boldText(this, i18n.t("supportTitle"), COLOR_TEXT, 28);
        title.setGravity(Gravity.CENTER);
        title.setPadding(0, dp(22), 0, 0);
        body.addView(title);

        TextView copy = Ui.text(this, i18n.t("supportBody"), COLOR_MUTED, 15);
        copy.setGravity(Gravity.CENTER);
        copy.setLineSpacing(dp(4), 1f);
        copy.setPadding(dp(10), dp(12), dp(10), dp(26));
        body.addView(copy);

        Button enter = filledButton(i18n.t("setupEnter"));
        enter.setOnClickListener(v -> {
            dialog.dismiss();
            renderMain();
        });
        body.addView(enter, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));

        Button support = quietButton(i18n.t("openSupport"));
        support.setOnClickListener(v -> startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://support.meqrcode.cn/"))));
        LinearLayout.LayoutParams supportParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        supportParams.setMargins(0, dp(10), 0, 0);
        body.addView(support, supportParams);
    }

    private View onboardingStepTitle(String number, String titleText, String bodyText) {
        LinearLayout block = new LinearLayout(this);
        block.setOrientation(LinearLayout.VERTICAL);
        TextView numberView = new TextView(this);
        numberView.setText(number);
        numberView.setTextColor(Ui.TEAL);
        numberView.setTextSize(15);
        numberView.setTypeface(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD);
        block.addView(numberView);
        TextView title = new TextView(this);
        title.setText(titleText);
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(29);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setLineSpacing(dp(2), 1f);
        title.setPadding(0, dp(7), 0, 0);
        block.addView(title);
        TextView copy = new TextView(this);
        copy.setText(bodyText);
        copy.setTextColor(COLOR_MUTED);
        copy.setTextSize(15);
        copy.setLineSpacing(dp(4), 1f);
        copy.setPadding(0, dp(10), 0, dp(26));
        block.addView(copy);
        return block;
    }

    private TextView onboardingMark() {
        TextView mark = new TextView(this);
        mark.setText("M");
        mark.setTextColor(Color.BLACK);
        mark.setTextSize(20);
        mark.setGravity(Gravity.CENTER);
        mark.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        mark.setBackground(rounded(Ui.TEAL, dp(13)));
        mark.setContentDescription(i18n.t("appName"));
        return mark;
    }

    private boolean saveOnboardingProfile() {
        editSession.profile.syncLegacyFields();
        profiles.add(editSession.profile);
        try {
            store.save(profiles);
        } catch (IOException exception) {
            profiles.remove(editSession.profile);
            toast(i18n.t("saveFailed"));
            return false;
        }
        getSharedPreferences("settings", MODE_PRIVATE).edit().putBoolean(ONBOARDING_VERSION, true).remove("onboardingDraft").apply();
        currentPage = Math.max(0, profiles.size() - 1);
        showingCardList = false;
        return true;
    }

    private void saveOnboardingDraft() {
        if (editSession == null || !editSession.onboarding || onboardingStep > 5) return;
        try {
            org.json.JSONObject saved = new org.json.JSONObject().put("step", onboardingStep)
                    .put("profile", editSession.profile.toJson())
                    .put("tagDraft", editSession.tags == null ? editSession.tagDraft : editSession.tags.getText().toString());
            getSharedPreferences("settings", MODE_PRIVATE).edit().putString("onboardingDraft", saved.toString()).apply();
        } catch (org.json.JSONException ignored) { }
    }

    @Override protected void onStop() {
        if (editSession != null && editSession.onboarding && onboardingStep <= 5) {
            syncOnboardingFields();
            saveOnboardingDraft();
        }
        super.onStop();
    }

    private TextWatcher directItemWatcher(MeQrItem item, EditText qr, EditText custom) {
        return new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence value, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence value, int start, int before, int count) {
                item.qrContent = qr.getText().toString();
                item.customPlatformName = custom.getText().toString();
            }
            @Override public void afterTextChanged(Editable value) { }
        };
    }

    private void syncOnboardingFields() {
        if (editSession == null) {
            return;
        }
        if (editSession.name != null) {
            editSession.profile.name = editSession.name.getText().toString().trim();
        }
        if (editSession.subtitle != null) {
            editSession.profile.subtitle = editSession.subtitle.getText().toString().trim();
        }
        if (editSession.passSubtitle != null) {
            editSession.profile.passSubtitle = limitPassSubtitle(value(editSession.passSubtitle, ""));
        }
        if (editSession.textColor != null) {
            editSession.profile.textColor = value(editSession.textColor, editSession.profile.textColor);
        }
        if (editSession.qrColor != null) {
            editSession.profile.qrColor = value(editSession.qrColor, editSession.profile.qrColor);
        }
        if (editSession.backgroundColor != null) {
            editSession.profile.backgroundColor = value(editSession.backgroundColor, editSession.profile.backgroundColor);
        }
    }

    private void showLanguagePicker() {
        showLanguagePicker(this::renderMain);
    }

    private void showLanguagePicker(Runnable onLanguageChanged) {
        String[] modes = {I18n.SYSTEM, I18n.ZH_HANS, I18n.ZH_HANT_HK, I18n.ZH_HANT_TW, I18n.EN, I18n.JA};
        String[] labels = new String[modes.length];
        for (int i = 0; i < modes.length; i++) {
            labels[i] = i18n.languageDisplayName(modes[i]);
        }
        String current = i18n.languageMode();

        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCanceledOnTouchOutside(true);

        LinearLayout sheet = new LinearLayout(this);
        sheet.setOrientation(LinearLayout.VERTICAL);
        sheet.setPadding(dp(16), dp(10), dp(16), Math.max(dp(18), navigationBottom() + dp(8)));
        sheet.setBackground(topRounded(COLOR_SURFACE, dp(20)));

        View handle = new View(this);
        handle.setBackground(rounded(Color.rgb(78, 89, 104), dp(2)));
        LinearLayout.LayoutParams handleParams = new LinearLayout.LayoutParams(dp(38), dp(4));
        handleParams.gravity = Gravity.CENTER_HORIZONTAL;
        handleParams.setMargins(0, 0, 0, dp(12));
        sheet.addView(handle, handleParams);

        TextView title = Ui.boldText(this, i18n.t("language"), COLOR_TEXT, 18);
        title.setIncludeFontPadding(false);
        title.setPadding(dp(6), dp(2), dp(6), dp(12));
        sheet.addView(title);

        LinearLayout rows = new LinearLayout(this);
        rows.setOrientation(LinearLayout.VERTICAL);
        rows.setBackground(rounded(COLOR_PANEL, dp(14), COLOR_SEPARATOR, dp(1)));
        for (int index = 0; index < modes.length; index++) {
            final int modeIndex = index;
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(dp(14), 0, dp(14), 0);
            row.setMinimumHeight(dp(56));
            row.setClickable(true);
            row.setFocusable(true);
            row.setOnClickListener(v -> {
                i18n.setLanguageMode(modes[modeIndex]);
                dialog.dismiss();
                onLanguageChanged.run();
            });

            TextView label = Ui.text(this, labels[index], COLOR_TEXT, 16);
            row.addView(label, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            if (modes[index].equals(current)) {
                ImageView check = UiIcons.view(this, "✓", Ui.TEAL);
                row.addView(check, new LinearLayout.LayoutParams(dp(28), dp(44)));
            }
            rows.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
            if (index < modes.length - 1) {
                rows.addView(separator());
            }
        }
        sheet.addView(rows);

        Button cancel = quietButton(i18n.t("cancel"));
        cancel.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        cancel.setOnClickListener(v -> dialog.dismiss());
        LinearLayout.LayoutParams cancelParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46));
        cancelParams.setMargins(0, dp(10), 0, 0);
        sheet.addView(cancel, cancelParams);

        dialog.setContentView(sheet);
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.gravity = Gravity.BOTTOM;
            attributes.width = ViewGroup.LayoutParams.MATCH_PARENT;
            attributes.height = ViewGroup.LayoutParams.WRAP_CONTENT;
            attributes.dimAmount = 0.58f;
            window.setAttributes(attributes);
        }
        dialog.show();
        if (window != null) {
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        }
    }

    private void showAbout() {
        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCanceledOnTouchOutside(true);

        LinearLayout sheet = new LinearLayout(this);
        sheet.setOrientation(LinearLayout.VERTICAL);
        sheet.setPadding(dp(16), dp(10), dp(16), Math.max(dp(18), navigationBottom() + dp(8)));
        sheet.setBackground(topRounded(COLOR_SURFACE, dp(20)));

        View handle = new View(this);
        handle.setBackground(rounded(Color.rgb(78, 89, 104), dp(2)));
        LinearLayout.LayoutParams handleParams = new LinearLayout.LayoutParams(dp(38), dp(4));
        handleParams.gravity = Gravity.CENTER_HORIZONTAL;
        handleParams.setMargins(0, 0, 0, dp(12));
        sheet.addView(handle, handleParams);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView headerTitle = Ui.boldText(this, i18n.t("about"), COLOR_TEXT, 18);
        header.addView(headerTitle, new LinearLayout.LayoutParams(0, dp(44), 1));
        Button close = iconButton("×");
        close.setContentDescription(i18n.t("done"));
        close.setOnClickListener(v -> dialog.dismiss());
        header.addView(close, new LinearLayout.LayoutParams(dp(40), dp(40)));
        sheet.addView(header);

        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(6), 0, dp(6), 0);

        ImageView appIcon = new ImageView(this);
        appIcon.setImageResource(R.mipmap.ic_launcher);
        appIcon.setScaleType(ImageView.ScaleType.FIT_CENTER);
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dp(88), dp(88));
        iconParams.gravity = Gravity.CENTER_HORIZONTAL;
        iconParams.setMargins(0, dp(4), 0, dp(10));
        root.addView(appIcon, iconParams);

        TextView app = Ui.boldText(this, i18n.t("appName"), COLOR_TEXT, 22);
        app.setGravity(Gravity.CENTER);
        root.addView(app);

        TextView version = Ui.text(this, i18n.t("version") + " " + appVersionName(), COLOR_MUTED, 13);
        version.setGravity(Gravity.CENTER);
        version.setPadding(0, dp(4), 0, dp(14));
        root.addView(version);

        root.addView(section(i18n.t("website")));
        LinearLayout webPanel = panel();
        webPanel.addView(linkButton("?  " + i18n.t("openSupport"), "https://support.meqrcode.cn/"));
        webPanel.addView(separator());
        webPanel.addView(linkButton(i18n.t("website"), "https://meqrcode.cn/"));
        root.addView(webPanel);

        root.addView(section(i18n.t("privacy")));
        LinearLayout legalPanel = panel();
        legalPanel.addView(linkButton("♢  " + i18n.t("privacy"), privacyUrl()));
        legalPanel.addView(separator());
        legalPanel.addView(linkButton(i18n.t("icpFiling") + "    粤ICP备2026097629号-2A", "https://beian.miit.gov.cn/"));
        root.addView(legalPanel);

        root.addView(section(i18n.t("contactDeveloper")));
        LinearLayout contactPanel = panel();
        contactPanel.addView(linkButton(i18n.t("email") + "    lucas_and_miku@icloud.com", "mailto:lucas_and_miku@icloud.com"));
        contactPanel.addView(separator());
        contactPanel.addView(linkButton("QID    Rebirth39", "https://qm.qq.com/q/ErpPGQuaAi"));
        root.addView(contactPanel);

        root.addView(section(i18n.t("developerIntro")));
        TextView developer = new TextView(this);
        developer.setText("重生Rebirth\n" + i18n.t("developerStudent") + "\n" + i18n.t("developerMadeForFun") + " " + i18n.t("developerUnexpected") + "\n" + i18n.t("developerHope"));
        developer.setTextSize(15);
        developer.setTextColor(COLOR_TEXT);
        developer.setLineSpacing(dp(2), 1.0f);
        root.addView(developer);

        scroll.addView(root);
        sheet.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        dialog.setContentView(sheet);
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.gravity = Gravity.BOTTOM;
            attributes.width = ViewGroup.LayoutParams.MATCH_PARENT;
            attributes.height = Math.round(getResources().getDisplayMetrics().heightPixels * 0.72f);
            attributes.dimAmount = 0.58f;
            window.setAttributes(attributes);
        }
        dialog.show();
        if (window != null) {
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT,
                    Math.round(getResources().getDisplayMetrics().heightPixels * 0.72f));
        }
    }

    private String appVersionName() {
        try {
            PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
            return info.versionName == null ? "" : info.versionName;
        } catch (PackageManager.NameNotFoundException exception) {
            return "";
        }
    }

    private String privacyUrl() {
        return "https://meqrcode.cn/privacy.html";
    }

    private void showMeQrCode(MeQrProfile profile) {
        MeQrExchangeCodeStore codeStore = new MeQrExchangeCodeStore(this);
        final MeQrExchangeCodeStore.Record code;
        try {
            String eventId = eventStore.activeEvent() == null ? null : eventStore.activeEvent().id;
            String fingerprint = MeQrExchangeCodeStore.fingerprint(profile, i18n, eventId);
            MeQrExchangeCodeStore.Record cached = codeStore.load(profile.id, fingerprint);
            code = cached == null ? MeQrExchangeCodeStore.create(profile, i18n, fingerprint, eventId) : cached;
            if (cached == null) codeStore.save(profile.id, code);
        } catch (Exception exception) {
            toast(i18n.t("meqrCodeFailed"));
            return;
        }
        encounterStore.registerOutgoingSession(code.sessionId, code.ownerToken);
        TextView mode = showExchangeCodeSheet(profile, code);

        if (code.synced) return;
        new Thread(() -> {
            try {
                MeQrRemoteService.publishExchangeCode(code);
                codeStore.markSynced(profile.id, code);
                runOnUiThread(() -> {
                    if (mode.isAttachedToWindow()) mode.setText(i18n.t("meqrOnlineReady"));
                });
            } catch (Exception exception) {
                runOnUiThread(() -> {
                    if (mode.isAttachedToWindow()) mode.setText(i18n.t("meqrOnlineFallback"));
                });
            }
        }).start();
    }

    private TextView showExchangeCodeSheet(MeQrProfile profile, MeQrExchangeCodeStore.Record code) {
        Bitmap currentCode = QrCodeGenerator.generateColorLayered(code.payload, code.avatar, 960);
        Dialog dialog = new Dialog(this, android.R.style.Theme_Material_Light_NoActionBar);
        FrameLayout shell = new FrameLayout(this);
        addPageBackground(shell, profile);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(0, statusTop(), 0, navigationBottom());
        shell.addView(page, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        FrameLayout toolbar = new FrameLayout(this);
        toolbar.setBackgroundColor(Color.argb(185, 255, 255, 255));
        TextView title = new TextView(this);
        title.setText(i18n.t("meqrProfileCode"));
        title.setTextColor(Color.BLACK);
        title.setTextSize(18);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.CENTER);
        title.setSingleLine(true);
        title.setEllipsize(android.text.TextUtils.TruncateAt.END);
        title.setPadding(dp(84), 0, dp(84), 0);
        toolbar.addView(title, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(60)));
        Button done = lightIconButton(i18n.t("done"));
        done.setTextSize(15);
        done.setContentDescription(i18n.t("done"));
        done.setOnClickListener(v -> dialog.dismiss());
        FrameLayout.LayoutParams doneParams = new FrameLayout.LayoutParams(dp(76), dp(44), Gravity.START | Gravity.CENTER_VERTICAL);
        doneParams.leftMargin = dp(8);
        toolbar.addView(done, doneParams);
        page.addView(toolbar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(60)));

        int contentWidth = Math.min(dp(370), getResources().getDisplayMetrics().widthPixels - dp(32));
        boolean rhodes = "rhodes".equals(profile.template);
        int cardWidth = Math.min(contentWidth, dp(rhodes ? 336 : 342));
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        page.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        LinearLayout center = new LinearLayout(this);
        center.setOrientation(LinearLayout.VERTICAL);
        center.setGravity(Gravity.CENTER_HORIZONTAL);
        scroll.addView(center);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(0, dp(18), 0, dp(24));
        center.addView(root, new LinearLayout.LayoutParams(contentWidth, ViewGroup.LayoutParams.WRAP_CONTENT));

        ImageView avatar = new ImageView(this);
        Bitmap avatarBitmap = decodeBitmap(profile.avatarPath);
        if (avatarBitmap != null) {
            avatar.setImageBitmap(circleBitmap(avatarBitmap, dp(52)));
        } else {
            avatar.setImageBitmap(initialBitmap(profile.name, dp(52), Color.DKGRAY, Color.WHITE));
        }
        root.addView(avatar, new LinearLayout.LayoutParams(dp(52), dp(52)));

        TextView name = new TextView(this);
        name.setText(cardTitle(profile));
        name.setTextColor(Color.BLACK);
        name.setTextSize(25);
        name.setTypeface(android.graphics.Typeface.create("sans-serif-black", android.graphics.Typeface.NORMAL));
        name.setPadding(0, dp(6), 0, dp(4));
        root.addView(name);
        MeQrExchangeProfile offline = MeQrExchangeCodec.offlineFallback(code.payload);
        if (offline != null && !offline.subtitle.isEmpty()) {
            TextView subtitle = new TextView(this);
            subtitle.setText(offline.subtitle);
            subtitle.setTextColor(Color.argb(200, 0, 0, 0));
            subtitle.setTextSize(14);
            subtitle.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
            root.addView(subtitle);
        }

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(rounded(Color.argb(rhodes ? 224 : 190, 255, 255, 255), dp(14), Color.argb(180, 255, 255, 255), dp(1)));
        card.setClipToOutline(true);
        LinearLayout.LayoutParams cardParams = new LinearLayout.LayoutParams(cardWidth, ViewGroup.LayoutParams.WRAP_CONTENT);
        cardParams.gravity = Gravity.CENTER_HORIZONTAL;
        cardParams.topMargin = dp(14);
        root.addView(card, cardParams);
        if (rhodes) {
            LinearLayout strip = new LinearLayout(this);
            for (String color : new String[]{profile.qrColor, profile.textColor, profile.backgroundColor}) {
                View segment = new View(this);
                segment.setBackgroundColor(CardRenderer.parseColor(color, Color.WHITE));
                segment.setAlpha(0.82f);
                strip.addView(segment, new LinearLayout.LayoutParams(0, dp(24), 1));
            }
            card.addView(strip);
        }
        LinearLayout cardBody = new LinearLayout(this);
        cardBody.setOrientation(LinearLayout.HORIZONTAL);
        card.addView(cardBody);
        if (rhodes) {
            View rail = new View(this) {
                @Override protected void onDraw(Canvas canvas) {
                    CardRenderer.drawRhodesRail(canvas, new RectF(0, 0, getWidth(), getHeight()),
                            CardRenderer.parseColor(profile.textColor, Color.BLACK), getResources().getDisplayMetrics().density, true);
                }
            };
            cardBody.addView(rail, new LinearLayout.LayoutParams(dp(52), ViewGroup.LayoutParams.MATCH_PARENT));
        }
        LinearLayout details = new LinearLayout(this);
        details.setOrientation(LinearLayout.VERTICAL);
        details.setPadding(dp(12), dp(12), dp(12), dp(14));
        cardBody.addView(details, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        ImageView qr = new ImageView(this);
        qr.setImageBitmap(currentCode);
        qr.setContentDescription(i18n.t("meqrProfileCode"));
        qr.setScaleType(ImageView.ScaleType.FIT_CENTER);
        qr.setBackground(rounded(Color.WHITE, dp(18), Color.argb(22, 0, 0, 0), dp(1)));
        qr.setPadding(dp(10), dp(10), dp(10), dp(10));
        int qrSide = Math.min(dp(rhodes ? 234 : 246), cardWidth - dp(rhodes ? 76 : 24));
        LinearLayout.LayoutParams qrParams = new LinearLayout.LayoutParams(qrSide, qrSide);
        qrParams.gravity = Gravity.CENTER_HORIZONTAL;
        qrParams.bottomMargin = dp(10);
        details.addView(qr, qrParams);

        TextView mode = new TextView(this);
        mode.setText(i18n.t(code.synced ? "meqrOnlineReady" : "meqrPreparingOnline"));
        mode.setTextColor(Color.argb(170, 0, 0, 0));
        mode.setTextSize(11);
        mode.setPadding(dp(4), 0, dp(4), dp(8));
        details.addView(mode);

        TextView hint = new TextView(this);
        hint.setText(i18n.t("meqrCodeHint"));
        hint.setTextColor(Color.argb(184, 0, 0, 0));
        hint.setTextSize(11);
        hint.setPadding(dp(4), 0, dp(4), dp(10));
        details.addView(hint);
        TagFlowLayout platforms = new TagFlowLayout(this);
        for (int i = 0; i < Math.min(3, profile.qrItems.size()); i++) {
            TextView chip = new TextView(this);
            chip.setText(profile.qrItems.get(i).platformDisplayName(i18n));
            chip.setTextColor(Color.BLACK);
            chip.setTextSize(13);
            chip.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
            chip.setPadding(dp(11), dp(7), dp(11), dp(7));
            chip.setBackground(rounded(Color.argb(194, 255, 255, 255), dp(24)));
            platforms.addView(chip, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        }
        details.addView(platforms);

        LinearLayout footer = new LinearLayout(this);
        footer.setGravity(Gravity.CENTER);
        footer.setPadding(dp(22), dp(8), dp(22), dp(12));
        footer.setBackgroundColor(Color.argb(110, 255, 255, 255));
        Button save = filledButton(i18n.t("saveMeQrCode"));
        save.setOnClickListener(v -> saveMeQrBitmap(currentCode));
        footer.addView(save, new LinearLayout.LayoutParams(Math.min(dp(360), getResources().getDisplayMetrics().widthPixels - dp(44)), dp(48)));
        page.addView(footer);
        dialog.setContentView(shell);
        handleDialogBack(dialog, dialog::dismiss);
        dialog.show();
        Window window = dialog.getWindow();
        if (window != null) {
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        }
        return mode;
    }

    private void saveMeQrBitmap(Bitmap bitmap) {
        if (Build.VERSION.SDK_INT <= 28 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            pendingMeQrBitmap = bitmap;
            requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQUEST_WRITE_PHOTOS);
            return;
        }
        Uri uri = saveBitmapToGallery(bitmap);
        if (uri == null) {
            toast(i18n.t("saveFailed"));
        } else {
            toast(i18n.t("saved"));
        }
    }

    private void showScan() {
        if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.CAMERA}, REQUEST_CAMERA);
            return;
        }
        openScanner();
    }

    private void openScanner() {
        new MeQrScannerDialog(this, i18n, new MeQrScannerDialog.Listener() {
            @Override
            public void onPayload(String payload, byte[] colorAvatarJpeg) {
                if (payload == null || payload.isEmpty()) {
                    toast(i18n.t("couldNotDecode"));
                    return;
                }
                handleMeQrPayload(payload, colorAvatarJpeg);
            }

            @Override
            public void onImportRequest() {
                choosingScanImage = true;
                chooseImage(PICK_SCAN_QR);
            }
        }).show();
    }

    private void handleMeQrPayload(String payload) {
        handleMeQrPayload(payload, null);
    }

    private void handleMeQrPayload(String payload, byte[] colorAvatarJpeg) {
        if (MeQrRemoteService.isEncounterSessionUrl(payload)) {
            new Thread(() -> {
                try {
                    MeQrRemoteService.EncounterSession session = MeQrRemoteService.fetchEncounterSession(payload);
                    if (session.creatorProfile == null) {
                        throw new IllegalStateException("Encounter session has no creator profile.");
                    }
                    MeQrExchangeProfile profile = applyColorAvatar(session.creatorProfile, colorAvatarJpeg);
                    runOnUiThread(() -> showEncounterPreview(profile, session.sessionId));
                } catch (Exception exception) {
                    MeQrExchangeProfile fallback = MeQrExchangeCodec.offlineFallback(payload);
                    runOnUiThread(() -> {
                        if (fallback != null) {
                            showEncounterPreview(applyColorAvatar(fallback, colorAvatarJpeg));
                        } else {
                            toast(i18n.t("couldNotDecode"));
                        }
                    });
                }
            }).start();
            return;
        }
        if (MeQrExchangeCodec.isRemoteUrl(payload)) {
            new Thread(() -> {
                try {
                    MeQrExchangeProfile profile = MeQrRemoteService.fetchProfile(payload);
                    runOnUiThread(() -> showEncounterPreview(applyColorAvatar(profile, colorAvatarJpeg)));
                } catch (Exception exception) {
                    MeQrExchangeProfile fallback = MeQrExchangeCodec.offlineFallback(payload);
                    runOnUiThread(() -> {
                        if (fallback != null) {
                            showEncounterPreview(applyColorAvatar(fallback, colorAvatarJpeg));
                        } else {
                            toast(i18n.t("couldNotDecode"));
                        }
                    });
                }
            }).start();
            return;
        }
        try {
            MeQrExchangeProfile profile = MeQrExchangeCodec.decode(payload);
            showEncounterPreview(applyColorAvatar(profile, colorAvatarJpeg));
            return;
        } catch (Exception ignored) {
        }
        if (routeGenericQR(payload)) {
            // Routed to an external app or the browser.
        } else {
            toast(i18n.t("notMeQrCode"));
        }
    }

    private boolean routeGenericQR(String payload) {
        if (payload == null || payload.isEmpty()) {
            return false;
        }
        long now = System.currentTimeMillis();
        if (payload.equals(lastRoutedPayload) && now - lastRoutedAt < 3000) {
            return true;
        }

        lastRoutedPayload = payload;
        lastRoutedAt = now;
        reviewQRLink(payload);
        return true;
    }

    private boolean reviewingQRLink;

    private void reviewQRLink(String content) {
        if (reviewingQRLink) return;
        java.net.URI url = QRLinkPolicy.webURL(content);
        TextView text = new TextView(this);
        text.setText(i18n.t("qrReviewWarning") + "\n\n" + (url == null ? "" : url.getHost() + "\n\n") + content);
        String warning = QRLinkPolicy.warningKey(content, QRLinkPolicy.platformID(content));
        if (warning != null) text.append("\n\n" + i18n.t(warning));
        text.setTextIsSelectable(true);
        text.setPadding(dp(24), dp(16), dp(24), dp(16));
        ScrollView scroll = new ScrollView(this);
        scroll.addView(text);
        AlertDialog.Builder builder = new AlertDialog.Builder(this).setTitle(i18n.t("qrReviewTitle"))
                .setView(scroll).setNegativeButton(i18n.t("cancel"), null);
        if (url != null) builder.setPositiveButton(i18n.t("openLink"), (d, w) -> {
            String platform = PlatformNames.detect(content);
            if ("wechat".equals(platform)) openWeChatScan();
            else if ("xiaohongshu".equals(platform)) openXiaohongshu(url.toString());
            else openExternal(Uri.parse(url.toString()));
        });
        reviewingQRLink = true;
        AlertDialog dialog = builder.create();
        dialog.setOnDismissListener(d -> { reviewingQRLink = false; lastRoutedAt = System.currentTimeMillis(); });
        dialog.show();
        styleAlert(dialog);
    }

    private void openWeChatScan() {
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("weixin://scanqrcode"));
        if (resolveActivity(intent)) {
            startActivity(intent);
        } else {
            toast(i18n.t("wechatNotInstalled"));
        }
    }

    private void openXiaohongshu(String payload) {
        String userID = xiaohongshuUserID(payload);
        if (userID != null) {
            openXiaohongshuApp(userID, payload);
            return;
        }
        new Thread(() -> {
            String resolved = resolveXiaohongshuRedirect(payload);
            String id = resolved == null ? null : xiaohongshuUserID(resolved);
            runOnUiThread(() -> {
                if (id != null) {
                    openXiaohongshuApp(id, resolved);
                } else {
                    openExternal(Uri.parse(payload));
                }
            });
        }).start();
    }

    private void openXiaohongshuApp(String userID, String fallback) {
        Uri schemeUri = Uri.parse("xhsdiscover://user/" + userID);
        if (resolveActivity(new Intent(Intent.ACTION_VIEW, schemeUri))) {
            startActivity(new Intent(Intent.ACTION_VIEW, schemeUri));
        } else {
            openExternal(Uri.parse(fallback));
        }
    }

    private String resolveXiaohongshuRedirect(String raw) {
        String url = raw;
        if (url.startsWith("http://")) {
            url = "https://" + url.substring("http://".length());
        }
        String key = url.toLowerCase(Locale.US);
        synchronized (xiaohongshuUserIDCache) {
            if (xiaohongshuUserIDCache.containsKey(key)) {
                return xiaohongshuUserIDCache.get(key);
            }
        }
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(url).openConnection();
            connection.setInstanceFollowRedirects(false);
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(5000);
            connection.setReadTimeout(8000);
            connection.setRequestProperty("User-Agent",
                    "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36");
            int status = connection.getResponseCode();
            if (status >= 300 && status < 400) {
                String location = connection.getHeaderField("Location");
                if (location != null && !location.isEmpty()) {
                    String resolved = new URL(new URL(url), location).toString();
                    synchronized (xiaohongshuUserIDCache) {
                        xiaohongshuUserIDCache.put(key, resolved);
                    }
                    return resolved;
                }
            }
        } catch (Exception ignored) {
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
        return url;
    }

    private String xiaohongshuUserID(String value) {
        java.net.URI url = QRLinkPolicy.webURL(value);
        if (url == null || !"xiaohongshu".equals(QRLinkPolicy.platformID(value))) {
            return null;
        }
        String path = url.getPath().toLowerCase(Locale.US);
        if (!path.matches("/user/profile/[0-9a-f]{24}")) return null;
        Matcher matcher = XHS_USER_ID.matcher(path);
        return matcher.find() ? matcher.group() : null;
    }

    private void openExternal(Uri uri) {
        if (QRLinkPolicy.webURL(uri.toString()) == null) return;
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (Exception ignored) {
        }
    }

    private boolean isHttpUrl(String value) {
        if (value == null) {
            return false;
        }
        String lower = value.toLowerCase(Locale.US);
        return lower.startsWith("http://") || lower.startsWith("https://");
    }

    private boolean resolveActivity(Intent intent) {
        return intent.resolveActivity(getPackageManager()) != null;
    }

    private MeQrExchangeProfile applyColorAvatar(MeQrExchangeProfile profile, byte[] colorAvatarJpeg) {
        if (profile == null || colorAvatarJpeg == null || colorAvatarJpeg.length == 0) {
            return profile;
        }
        int currentBytes = 0;
        try {
            currentBytes = android.util.Base64.decode(profile.avatarBase64, android.util.Base64.DEFAULT).length;
        } catch (Exception ignored) {
        }
        if (colorAvatarJpeg.length > currentBytes) {
            profile.avatarBase64 = android.util.Base64.encodeToString(colorAvatarJpeg, android.util.Base64.NO_WRAP);
        }
        return profile;
    }

    private void showEncounterPreview(MeQrExchangeProfile profile) {
        showEncounterPreview(profile, null);
    }

    private void showEncounterPreview(MeQrExchangeProfile profile, String sessionID) {
        if (profile == null) {
            toast(i18n.t("couldNotDecode"));
            return;
        }
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(16), dp(20), dp(16));
        root.setBackgroundColor(COLOR_BG);

        root.addView(heading(i18n.t("meqrProfileFound")));

        LinearLayout header = panel();
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(16), dp(14), dp(16), dp(14));
        ImageView avatar = new ImageView(this);
        Bitmap avatarBitmap = base64Bitmap(profile.avatarBase64);
        if (avatarBitmap != null) {
            avatar.setImageBitmap(circleBitmap(avatarBitmap, dp(64)));
        } else {
            avatar.setImageBitmap(initialBitmap(profile.name, dp(64), Color.rgb(57, 197, 187), Color.WHITE));
        }
        header.addView(avatar, new LinearLayout.LayoutParams(dp(64), dp(64)));

        LinearLayout nameBlock = new LinearLayout(this);
        nameBlock.setOrientation(LinearLayout.VERTICAL);
        nameBlock.setPadding(dp(14), 0, 0, 0);
        TextView name = new TextView(this);
        name.setText(profile.name == null || profile.name.trim().isEmpty() ? i18n.t("unknownContact") : profile.name.trim());
        name.setTextSize(20);
        name.setTextColor(COLOR_TEXT);
        name.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        nameBlock.addView(name);
        String profileIntro = profile.intro == null || profile.intro.trim().isEmpty() ? profile.subtitle : profile.intro;
        if (profileIntro != null && !profileIntro.trim().isEmpty()) {
            TextView subtitle = new TextView(this);
            subtitle.setText(profileIntro.trim());
            subtitle.setTextSize(14);
            subtitle.setTextColor(COLOR_MUTED);
            subtitle.setPadding(0, dp(4), 0, 0);
            nameBlock.addView(subtitle);
        }
        header.addView(nameBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        root.addView(header);

        Bitmap bannerBitmap = base64Bitmap(profile.bannerBase64);
        if (bannerBitmap != null) {
            ImageView banner = new ImageView(this);
            banner.setImageBitmap(bannerBitmap);
            banner.setScaleType(ImageView.ScaleType.CENTER_CROP);
            banner.setBackground(rounded(COLOR_SURFACE, dp(14)));
            LinearLayout.LayoutParams bannerParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(110));
            bannerParams.setMargins(0, dp(12), 0, 0);
            root.addView(banner, bannerParams);
        }

        if (!profile.platforms.isEmpty()) {
            root.addView(section(i18n.t("platformsFromMeQr")));
            LinearLayout platformsPanel = panel();
            for (int i = 0; i < profile.platforms.size(); i++) {
                MeQrExchangeProfile.Platform platform = profile.platforms.get(i);
                if (i > 0) {
                    platformsPanel.addView(separator());
                }
                platformsPanel.addView(encounterPlatformRow(platform));
            }
            root.addView(platformsPanel);
        }

        MeQrEvent activeEvent = eventStore.activeEvent();
        if (activeEvent != null) {
            root.addView(section(i18n.t("activeEvent")));
            LinearLayout eventPanel = panel();
            TextView eventTitle = new TextView(this);
            eventTitle.setText(eventDisplayTitle(activeEvent));
            eventTitle.setTextSize(17);
            eventTitle.setTextColor(COLOR_TEXT);
            eventTitle.setPadding(dp(16), dp(12), dp(16), dp(4));
            eventPanel.addView(eventTitle);
            if (activeEvent.venue != null && !activeEvent.venue.isEmpty()) {
                TextView eventVenue = new TextView(this);
                eventVenue.setText(i18n.t("eventVenue") + ": " + eventDisplayVenue(activeEvent));
                eventVenue.setTextSize(14);
                eventVenue.setTextColor(COLOR_MUTED);
                eventVenue.setPadding(dp(16), 0, dp(16), dp(12));
                eventPanel.addView(eventVenue);
            }
            root.addView(eventPanel);
        }

        Button save = filledButton(i18n.t("saveEncounter"));
        save.setOnClickListener(v -> {
            encounterStore.add(profile, eventStore.activeEvent(), sessionID);
            if (sessionID != null && !sessionID.isEmpty()) {
                MeQrProfile local = currentEncounterProfile();
                if (local != null) {
                    try {
                        org.json.JSONObject localJson = MeQrExchangeCodec.onlineProfile(local, i18n);
                        new Thread(() -> {
                            try {
                                MeQrRemoteService.confirmEncounterSession(sessionID, localJson);
                            } catch (Exception ignored) {
                            }
                        }).start();
                    } catch (Exception ignored) {
                    }
                }
            }
            toast(i18n.t("savedEncounter"));
            AlertDialog dialog = (AlertDialog) root.getTag();
            if (dialog != null) {
                dialog.dismiss();
            }
        });
        LinearLayout.LayoutParams saveParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(54));
        saveParams.setMargins(0, dp(14), 0, 0);
        root.addView(save, saveParams);

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        root.setTag(dialog);
        styleAlert(dialog);
    }

    private MeQrProfile currentEncounterProfile() {
        if (profiles.isEmpty()) {
            return null;
        }
        int index = Math.max(0, Math.min(currentPage, profiles.size() - 1));
        return profiles.get(index);
    }

    private LinearLayout encounterPlatformRow(MeQrExchangeProfile.Platform platform) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(14), dp(10), dp(14), dp(10));
        row.setOrientation(LinearLayout.HORIZONTAL);

        String content = platform.qrContent == null ? "" : platform.qrContent.trim();
        ImageView qr = new ImageView(this);
        qr.setImageBitmap(QrCodeGenerator.generate(content.isEmpty() ? "MeQR" : content, Color.BLACK, 108));
        qr.setBackground(Ui.rounded(Color.WHITE, dp(10)));
        qr.setPadding(dp(5), dp(5), dp(5), dp(5));
        row.addView(qr, new LinearLayout.LayoutParams(dp(64), dp(64)));

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        info.setPadding(dp(12), 0, 0, 0);
        TextView name = new TextView(this);
        name.setText(platform.name == null || platform.name.trim().isEmpty() ? i18n.t("custom") : platform.name.trim());
        name.setTextSize(16);
        name.setTextColor(COLOR_TEXT);
        name.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        info.addView(name);
        if (!content.isEmpty()) {
            TextView qrContent = new TextView(this);
            qrContent.setText(content);
            qrContent.setTextSize(12);
            qrContent.setTextColor(COLOR_MUTED);
            qrContent.setMaxLines(2);
            qrContent.setEllipsize(android.text.TextUtils.TruncateAt.END);
            qrContent.setPadding(0, dp(3), 0, 0);
            info.addView(qrContent);
        }
        row.addView(info, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        if (canOpenLink(content)) {
            Button open = lightActionButton("↗");
            open.setContentDescription(i18n.t("openLink"));
            open.setOnClickListener(v -> reviewQRLink(content));
            row.addView(open, new LinearLayout.LayoutParams(dp(52), dp(48)));
        }
        return row;
    }

    private boolean canOpenLink(String content) {
        return QRLinkPolicy.webURL(content) != null;
    }

    private void showEncounters() {
        int pendingBeforeSync = encounterStore.pendingCount();
        final AlertDialog[] dialogRef = new AlertDialog[1];
        encounterStore.syncPendingSessions(() -> runOnUiThread(() -> {
            if (pendingBeforeSync > 0 && encounterStore.pendingCount() < pendingBeforeSync) {
                if (dialogRef[0] != null && dialogRef[0].isShowing()) {
                    dialogRef[0].dismiss();
                }
                showEncounters();
            }
        }));
        List<EncounterRecord> records = encounterStore.records();
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(12), dp(18), dp(12));
        root.setBackgroundColor(COLOR_BG);

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setOrientation(LinearLayout.HORIZONTAL);
        TextView title = heading(i18n.t("encounters"));
        header.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        root.addView(header);

        if (encounterStore.pendingCount() > 0) {
            TextView pending = Ui.text(this, i18n.t("encounterWaiting"), COLOR_MUTED, 13);
            pending.setPadding(0, dp(2), 0, dp(8));
            root.addView(pending);
        }

        MeQrEvent currentEvent = eventStore.activeEvent();
        Button eventButton = actionButton(i18n.t("activeEvent") + ": " + (currentEvent == null ? i18n.t("noActiveEvent") : eventDisplayTitle(currentEvent)));
        eventButton.setGravity(Gravity.LEFT);
        eventButton.setPadding(dp(16), 0, dp(16), 0);
        eventButton.setTextColor(COLOR_BLUE);
        eventButton.setSingleLine(true);
        eventButton.setEllipsize(android.text.TextUtils.TruncateAt.END);
        eventButton.setOnClickListener(v -> showEventCenter());
        root.addView(eventButton, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        ScrollView scroll = new ScrollView(this);
        LinearLayout listContainer = new LinearLayout(this);
        listContainer.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(listContainer);
        addCappedScrollView(root, scroll, 0.6);

        if (records.isEmpty()) {
            LinearLayout empty = new LinearLayout(this);
            empty.setOrientation(LinearLayout.VERTICAL);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(22), dp(44), dp(22), dp(44));
            empty.setBackground(rounded(COLOR_SURFACE, dp(24)));
            TextView icon = Ui.text(this, "◉", Ui.BLUE, 40);
            icon.setGravity(Gravity.CENTER);
            empty.addView(icon);
            TextView emptyTitle = Ui.boldText(this, i18n.t("noEncounters"), COLOR_TEXT, 19);
            emptyTitle.setGravity(Gravity.CENTER);
            emptyTitle.setPadding(0, dp(10), 0, dp(6));
            empty.addView(emptyTitle);
            TextView emptyBody = Ui.text(this, i18n.t("noEncountersHint"), COLOR_MUTED, 14);
            emptyBody.setGravity(Gravity.CENTER);
            empty.addView(emptyBody);
            listContainer.addView(empty, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        } else {
            for (EncounterRecord record : records) {
                LinearLayout row = new LinearLayout(this);
                row.setGravity(Gravity.CENTER_VERTICAL);
                row.setOrientation(LinearLayout.HORIZONTAL);
                row.setPadding(dp(14), dp(12), dp(8), dp(12));
                row.setBackground(rounded(COLOR_SURFACE, dp(18)));
                row.setClickable(true);
                row.setOnClickListener(v -> showEncounterDetail(record));

                ImageView avatar = new ImageView(this);
                Bitmap avatarBitmap = base64Bitmap(record.avatarBase64);
                if (avatarBitmap != null) {
                    avatar.setImageBitmap(circleBitmap(avatarBitmap, dp(48)));
                } else {
                    avatar.setImageBitmap(initialBitmap(record.name, dp(48), Color.rgb(57, 197, 187), Color.WHITE));
                }
                row.addView(avatar, new LinearLayout.LayoutParams(dp(48), dp(48)));

                LinearLayout info = new LinearLayout(this);
                info.setOrientation(LinearLayout.VERTICAL);
                info.setPadding(dp(12), 0, 0, 0);
                TextView name = Ui.boldText(this, record.name == null || record.name.trim().isEmpty() ? i18n.t("unknownContact") : record.name.trim(), COLOR_TEXT, 16);
                info.addView(name);
                String summary = record.subtitle;
                if ((summary == null || summary.trim().isEmpty()) && !record.profiles.isEmpty()) {
                    StringBuilder platforms = new StringBuilder();
                    for (int i = 0; i < Math.min(3, record.profiles.size()); i++) {
                        if (platforms.length() > 0) {
                            platforms.append(" / ");
                        }
                        String platformName = record.profiles.get(i).name;
                        platforms.append(platformName == null || platformName.isEmpty() ? i18n.t("custom") : platformName);
                    }
                    summary = platforms.toString();
                }
                if (summary != null && !summary.trim().isEmpty()) {
                    TextView subtitle = Ui.text(this, summary.trim(), COLOR_MUTED, 13);
                    subtitle.setMaxLines(2);
                    subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
                    info.addView(subtitle);
                }
                if (record.eventTitle != null && !record.eventTitle.isEmpty()) {
                    TextView event = Ui.text(this, "◈ " + record.eventTitle, Ui.BLUE, 12);
                    event.setPadding(0, dp(3), 0, 0);
                    info.addView(event);
                }
                row.addView(info, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

                Button more = iconButton("⋯");
                more.setOnClickListener(v -> confirmDeleteEncounter(record));
                row.addView(more, new LinearLayout.LayoutParams(dp(44), dp(44)));

                LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                rowParams.setMargins(0, 0, 0, dp(10));
                listContainer.addView(row, rowParams);
            }
        }

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        dialogRef[0] = dialog;
        styleAlert(dialog);
    }

    private void confirmDeleteEncounter(EncounterRecord record) {
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("deleteEncounter"))
                .setMessage(i18n.t("deleteEncounterConfirm"))
                .setPositiveButton(i18n.t("delete"), (d, which) -> {
                    encounterStore.delete(record);
                    toast(i18n.t("done"));
                })
                .setNegativeButton(i18n.t("cancel"), null)
                .show();
        styleAlert(dialog);
    }

    private void showEncounterDetail(EncounterRecord record) {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(12), dp(18), dp(12));
        root.setBackgroundColor(COLOR_BG);
        root.addView(heading(record.name == null || record.name.trim().isEmpty() ? i18n.t("unknownContact") : record.name.trim()));

        LinearLayout identity = panel();
        identity.setGravity(Gravity.CENTER_VERTICAL);
        identity.setOrientation(LinearLayout.HORIZONTAL);
        identity.setPadding(dp(16), dp(14), dp(16), dp(14));
        ImageView identityAvatar = new ImageView(this);
        Bitmap identityBitmap = base64Bitmap(record.avatarBase64);
        identityAvatar.setImageBitmap(identityBitmap != null
                ? circleBitmap(identityBitmap, dp(64))
                : initialBitmap(record.name, dp(64), Color.rgb(57, 197, 187), Color.WHITE));
        identity.addView(identityAvatar, new LinearLayout.LayoutParams(dp(64), dp(64)));
        LinearLayout identityText = new LinearLayout(this);
        identityText.setOrientation(LinearLayout.VERTICAL);
        identityText.setPadding(dp(14), 0, 0, 0);
        identityText.addView(Ui.boldText(this,
                record.name == null || record.name.trim().isEmpty() ? i18n.t("unknownContact") : record.name.trim(),
                COLOR_TEXT, 20));
        if (record.subtitle != null && !record.subtitle.trim().isEmpty()) {
            TextView identitySubtitle = Ui.text(this, record.subtitle.trim(), COLOR_MUTED, 14);
            identitySubtitle.setMaxLines(4);
            identitySubtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
            identitySubtitle.setPadding(0, dp(4), 0, 0);
            identityText.addView(identitySubtitle);
        }
        identity.addView(identityText, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        root.addView(identity);

        ScrollView scroll = new ScrollView(this);
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(form);
        addCappedScrollView(root, scroll, 0.65);

        form.addView(section(i18n.t("encounterInfo")));
        LinearLayout infoPanel = panel();
        EditText note = Ui.field(this, i18n.t("note"), record.note, true);
        infoPanel.addView(note);
        infoPanel.addView(separator());
        EditText tags = Ui.field(this, i18n.t("tags"), String.join(" ", record.tags), false);
        infoPanel.addView(tags);
        infoPanel.addView(separator());
        EditText followStatus = Ui.field(this, i18n.t("followStatus"), record.followStatus == null ? "" : record.followStatus, false);
        infoPanel.addView(followStatus);
        infoPanel.addView(separator());
        infoPanel.addView(encounterToggle(i18n.t("needsPhotoReturn"), record.needsPhotoReturn, value -> record.needsPhotoReturn = value));
        infoPanel.addView(separator());
        infoPanel.addView(encounterToggle(i18n.t("exchangedFreebie"), record.exchangedFreebie, value -> record.exchangedFreebie = value));
        form.addView(infoPanel);

        if (!record.profiles.isEmpty()) {
            form.addView(section(i18n.t("platformsFromMeQr")));
            LinearLayout platformsPanel = panel();
            for (int i = 0; i < record.profiles.size(); i++) {
                if (i > 0) {
                    platformsPanel.addView(separator());
                }
                platformsPanel.addView(encounterPlatformRow(record.profiles.get(i)));
            }
            form.addView(platformsPanel);
        }

        Button save = filledButton(i18n.t("save"));
        save.setOnClickListener(v -> {
            record.note = note.getText().toString().trim();
            record.tags.clear();
            for (String raw : tags.getText().toString().split("[\\n\\r,， ]+", -1)) {
                String tag = MeQrProfile.normalizeTag(raw);
                if (!tag.isEmpty() && !record.tags.contains(tag)) {
                    record.tags.add(tag);
                }
            }
            String follow = followStatus.getText().toString().trim();
            record.followStatus = follow.isEmpty() ? null : follow;
            encounterStore.update(record);
            toast(i18n.t("done"));
            AlertDialog dialog = (AlertDialog) root.getTag();
            if (dialog != null) {
                dialog.dismiss();
            }
        });
        LinearLayout.LayoutParams saveParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
        saveParams.setMargins(0, dp(10), 0, 0);
        root.addView(save, saveParams);

        Button delete = quietButton(i18n.t("deleteEncounter"));
        delete.setTextColor(Color.rgb(255, 105, 122));
        delete.setOnClickListener(v -> {
            encounterStore.delete(record);
            toast(i18n.t("done"));
            AlertDialog dialog = (AlertDialog) root.getTag();
            if (dialog != null) {
                dialog.dismiss();
            }
        });
        form.addView(delete, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        root.setTag(dialog);
        styleAlert(dialog);
    }

    private View encounterToggle(String label, boolean initial, java.util.function.Consumer<Boolean> onChange) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(dp(16), dp(10), dp(16), dp(10));
        TextView text = Ui.text(this, label, COLOR_TEXT, 16);
        text.setPadding(dp(14), 0, 0, 0);
        row.addView(text, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        android.widget.Switch toggle = new android.widget.Switch(this);
        toggle.setContentDescription(label);
        toggle.setChecked(initial);
        toggle.setOnCheckedChangeListener((button, checked) -> onChange.accept(checked));
        row.addView(toggle, new LinearLayout.LayoutParams(dp(84), dp(42)));
        return row;
    }

    private void showEventCenter() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(12), dp(18), dp(12));
        root.setBackgroundColor(COLOR_BG);

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setOrientation(LinearLayout.HORIZONTAL);
        TextView title = heading(i18n.t("events"));
        header.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        Button add = actionButton("＋ " + i18n.t("addEvent"));
        add.setOnClickListener(v -> showAddEvent());
        header.addView(add);
        root.addView(header);

        ScrollView eventScroll = new ScrollView(this);
        LinearLayout listContainer = new LinearLayout(this);
        listContainer.setOrientation(LinearLayout.VERTICAL);
        eventScroll.addView(listContainer);
        addCappedScrollView(root, eventScroll, 0.5);

        listContainer.addView(eventRow(null));
        for (MeQrEvent event : eventStore.events()) {
            listContainer.addView(eventRow(event));
        }

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        styleAlert(dialog);
    }

    private View eventRow(MeQrEvent event) {
        boolean selected = event != null && eventStore.activeEvent() != null && eventStore.activeEvent().id.equals(event.id);
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(dp(16), dp(12), dp(12), dp(12));
        row.setBackground(rounded(selected ? Color.argb(38, 57, 197, 187) : COLOR_SURFACE, dp(16),
                selected ? Ui.TEAL : Ui.BORDER, dp(1)));

        TextView marker = Ui.text(this, event == null ? "○" : "◉", selected ? Ui.TEAL : Ui.DIM, 18);
        row.addView(marker, new LinearLayout.LayoutParams(dp(34), ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        info.setPadding(dp(6), 0, 0, 0);
        TextView name = Ui.boldText(this, event == null ? i18n.t("noActiveEvent") : eventDisplayTitle(event), selected ? Ui.TEAL : COLOR_TEXT, 16);
        info.addView(name);
        if (event != null) {
            String venueText = eventDisplayVenue(event);
            if (venueText != null && !venueText.isEmpty()) {
                TextView venue = Ui.text(this, venueText, COLOR_MUTED, 13);
                info.addView(venue);
            }
        }
        row.addView(info, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        if (event != null && event.isCustom) {
            Button remove = iconButton("×");
            remove.setOnClickListener(v -> {
                eventStore.deleteCustomEvent(event);
                toast(i18n.t("done"));
            });
            row.addView(remove, new LinearLayout.LayoutParams(dp(44), dp(44)));
        }
        row.setOnClickListener(v -> {
            eventStore.setActiveEvent(event);
            toast(i18n.t("done"));
        });
        LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rowParams.setMargins(0, 0, 0, dp(8));
        row.setLayoutParams(rowParams);
        return row;
    }

    private void showAddEvent() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(14), dp(20), dp(14));
        root.setBackgroundColor(COLOR_BG);
        root.addView(heading(i18n.t("addEvent")));

        LinearLayout panel = panel();
        EditText title = Ui.field(this, i18n.t("eventTitle"), "", false);
        panel.addView(title);
        panel.addView(separator());
        EditText venue = Ui.field(this, i18n.t("eventVenue"), "", false);
        panel.addView(venue);
        panel.addView(separator());
        EditText details = Ui.field(this, i18n.t("eventDetails"), "", true);
        panel.addView(details);
        root.addView(panel);

        Button save = filledButton(i18n.t("save"));
        save.setOnClickListener(v -> {
            if (title.getText().toString().trim().isEmpty()) {
                toast(i18n.t("nameRequired"));
                return;
            }
            MeQrEvent event = eventStore.addCustomEvent(title.getText().toString(), venue.getText().toString(), details.getText().toString());
            eventStore.setActiveEvent(event);
            toast(i18n.t("done"));
            AlertDialog dialog = (AlertDialog) root.getTag();
            if (dialog != null) {
                dialog.dismiss();
            }
        });
        root.addView(save, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("cancel"), null).show();
        root.setTag(dialog);
        styleAlert(dialog);
    }

    private Bitmap base64Bitmap(String base64) {
        if (base64 == null || base64.isEmpty()) {
            return null;
        }
        try {
            String value = base64.trim();
            int comma = value.indexOf(',');
            if (value.startsWith("data:") && comma >= 0) {
                value = value.substring(comma + 1);
            }
            byte[] bytes;
            try {
                bytes = android.util.Base64.decode(value, android.util.Base64.DEFAULT);
            } catch (IllegalArgumentException exception) {
                bytes = android.util.Base64.decode(value, android.util.Base64.URL_SAFE | android.util.Base64.NO_WRAP);
            }
            return BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
        } catch (Exception exception) {
            return null;
        }
    }

    private int parseUiColor(String value, int fallback) {
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        try {
            return Color.parseColor(value.trim());
        } catch (IllegalArgumentException exception) {
            return fallback;
        }
    }

    private Button linkButton(String text, String url) {
        Button button = actionButton(text);
        button.setOnClickListener(v -> startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))));
        return button;
    }

    private MeQrProfile copy(MeQrProfile source) {
        MeQrProfile copy = new MeQrProfile();
        copy.id = source.id;
        copy.name = source.name;
        copy.subtitle = source.subtitle;
        copy.platform = source.platform;
        copy.customPlatformName = source.customPlatformName;
        copy.qrContent = source.qrContent;
        copy.qrItems.clear();
        for (MeQrItem item : source.qrItems) {
            copy.qrItems.add(item.copy());
        }
        copy.tags.clear();
        copy.tags.addAll(source.tags);
        copy.tagColorOverrides.clear();
        copy.tagColorOverrides.putAll(source.tagColorOverrides);
        copy.tagTextWeights.putAll(source.tagTextWeights);
        for (TagReference reference : source.tagReferences) {
            try { copy.tagReferences.add(TagReference.fromJson(reference.toJson())); }
            catch (org.json.JSONException error) { throw new IllegalStateException("Could not copy Tag reference", error); }
        }
        copy.template = source.template;
        copy.passSubtitle = source.passSubtitle;
        copy.avatarPath = source.avatarPath;
        copy.backgroundPath = source.backgroundPath;
        copy.bannerPath = source.bannerPath;
        copy.backgroundColor = source.backgroundColor;
        copy.borderColor = source.borderColor;
        copy.textColor = source.textColor;
        copy.qrColor = source.qrColor;
        copy.cornerRadius = source.cornerRadius;
        copy.cardOpacity = source.cardOpacity;
        copy.createdAt = source.createdAt;
        copy.sortOrder = source.sortOrder;
        return copy;
    }

    private String joinTags(List<String> tags) {
        StringBuilder builder = new StringBuilder();
        for (String tag : tags) {
            if (builder.length() > 0) {
                builder.append('\n');
            }
            builder.append(tag);
        }
        return builder.toString();
    }

    private String joinTagsInline(List<String> tags) {
        StringBuilder builder = new StringBuilder();
        for (String tag : tags) {
            if (builder.length() > 0) {
                builder.append(" · ");
            }
            builder.append(tag);
        }
        return builder.toString();
    }

    private void addSummaryRow(LinearLayout parent, String title, String detail) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(14), dp(12), dp(14), dp(12));

        LinearLayout text = new LinearLayout(this);
        text.setOrientation(LinearLayout.VERTICAL);
        TextView titleView = Ui.boldText(this, title, COLOR_TEXT, 15);
        text.addView(titleView);
        TextView detailView = Ui.text(this, detail, COLOR_MUTED, 13);
        detailView.setPadding(0, dp(2), 0, 0);
        text.addView(detailView);
        row.addView(text, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        parent.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
    }

    private Button templateButton(String text, boolean selected) {
        Button button = new Button(this);
        normalizeButton(button);
        button.setAllCaps(false);
        button.setText(text);
        button.setTextSize(13);
        button.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        button.setTextColor(selected ? Color.BLACK : COLOR_MUTED);
        button.setBackground(rounded(selected ? Color.rgb(57, 197, 187) : COLOR_PANEL_2, dp(10)));
        return button;
    }

    private void styleTemplateButtons(Button selected, Button other) {
        selected.setTextColor(Color.BLACK);
        selected.setBackground(rounded(Color.rgb(57, 197, 187), dp(10)));
        other.setTextColor(COLOR_MUTED);
        other.setBackground(rounded(COLOR_PANEL_2, dp(10)));
    }

    private TextView heading(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(22);
        view.setTextColor(COLOR_TEXT);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(0, dp(8), 0, dp(12));
        return view;
    }

    private TextView section(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(16);
        view.setTextColor(COLOR_MUTED);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(dp(2), dp(22), 0, dp(8));
        return view;
    }

    private TextView label(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(14);
        view.setTextColor(COLOR_MUTED);
        view.setPadding(0, dp(8), 0, dp(4));
        return view;
    }

    private EditText field(String hint, String value, boolean multiline) {
        EditText edit = new EditText(this);
        edit.setHint(hint);
        edit.setText(value);
        edit.setTextSize(18);
        edit.setTextColor(COLOR_TEXT);
        edit.setHintTextColor(Color.rgb(118, 118, 124));
        edit.setBackgroundColor(Color.TRANSPARENT);
        edit.setPadding(dp(14), dp(8), dp(14), dp(8));
        edit.setSingleLine(!multiline);
        edit.setMinLines(multiline ? 2 : 1);
        edit.setGravity(multiline ? Gravity.TOP : Gravity.CENTER_VERTICAL);
        edit.setInputType(multiline ? InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE : InputType.TYPE_CLASS_TEXT);
        edit.setSelectAllOnFocus(false);
        return edit;
    }

    private EditText colorField(String hint, String value) {
        EditText edit = field(hint + " (#RRGGBB)", value, false);
        edit.setInputType(InputType.TYPE_CLASS_TEXT);
        return edit;
    }

    private Button toolbarButton(String text) {
        Button button = pillButton(text, true);
        button.setText(text);
        button.setTextSize(18);
        return button;
    }

    private Button smallButton(String text) {
        Button button = quietButton(text);
        button.setText(text);
        button.setTextSize(13);
        button.setAllCaps(false);
        return button;
    }

    private Button button(String text) {
        Button button = quietButton(text);
        button.setText(text);
        button.setAllCaps(false);
        return button;
    }

    private Button iconButton(String text) {
        Button button = new UiIcons.IconButton(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_TEXT);
        button.setTextSize(20);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(COLOR_SURFACE, dp(12), Ui.BORDER, dp(1)));
        return button;
    }

    private Button fabButton(String text) {
        Button button = new UiIcons.IconButton(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(30);
        button.setGravity(Gravity.CENTER);
        button.setElevation(dp(8));
        button.setBackground(Ui.tealButton(dp(33)));
        return button;
    }

    private Button lightFabButton(String text) {
        Button button = new UiIcons.IconButton(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.BLACK);
        button.setTextSize(30);
        button.setGravity(Gravity.CENTER);
        button.setElevation(dp(8));
        button.setBackground(rounded(Color.argb(230, 255, 255, 255), dp(33), Color.argb(120, 255, 255, 255), dp(1)));
        return button;
    }

    private Button lightIconButton(String text) {
        Button button = new UiIcons.IconButton(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.BLACK);
        button.setTextSize(19);
        button.setGravity(Gravity.CENTER);
        button.setElevation(dp(2));
        button.setBackground(rounded(Color.argb(220, 255, 255, 255), dp(12), Color.argb(130, 255, 255, 255), dp(1)));
        return button;
    }

    private Button lightActionButton(String text) {
        Button button = new UiIcons.IconButton(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.rgb(20, 20, 20));
        button.setTextSize(13);
        button.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(Color.argb(204, 255, 255, 255), dp(11), Color.argb(90, 20, 20, 20), dp(1)));
        return button;
    }

    private Button filledButton(String text) {
        Button button = new Button(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(15);
        button.setGravity(Gravity.CENTER);
        button.setBackground(Ui.tealButton(dp(12)));
        return button;
    }

    private TextView chip(String text, int backgroundColor, int textColor) {
        TextView chip = new TextView(this);
        chip.setText(text);
        chip.setTextColor(textColor);
        chip.setTextSize(15);
        chip.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dp(18), dp(8), dp(18), dp(8));
        chip.setBackground(rounded(backgroundColor, dp(20)));
        return chip;
    }

    private Button rowButton(String leading, String trailing) {
        Button button = new Button(this);
        normalizeButton(button);
        button.setText(leading);
        android.graphics.drawable.Drawable arrow = getDrawable(R.drawable.ic_expand_more).mutate();
        arrow.setTint(COLOR_MUTED);
        arrow.setBounds(0, 0, dp(24), dp(24));
        button.setCompoundDrawablesRelative(null, null, arrow, null);
        button.setAllCaps(false);
        button.setTextColor(COLOR_TEXT);
        button.setTextSize(18);
        button.setGravity(Gravity.CENTER_VERTICAL | Gravity.LEFT);
        button.setPadding(dp(14), 0, dp(14), 0);
        button.setBackgroundColor(Color.TRANSPARENT);
        return button;
    }

    private LinearLayout panel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(12), dp(7), dp(12), dp(7));
        panel.setBackground(rounded(COLOR_PANEL, dp(16), Ui.BORDER, dp(1)));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, 0, dp(8));
        panel.setLayoutParams(params);
        return panel;
    }

    private View separator() {
        View view = new View(this);
        view.setBackgroundColor(COLOR_SEPARATOR);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Math.max(1, dp(1)));
        params.setMargins(dp(14), dp(4), dp(14), dp(4));
        view.setLayoutParams(params);
        return view;
    }

    private TextView panelLabel(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(18);
        view.setTextColor(COLOR_TEXT);
        view.setPadding(dp(14), dp(10), dp(14), dp(4));
        return view;
    }

    private EditText addColorRow(LinearLayout parent, String label, String value) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(dp(14), dp(4), dp(10), dp(4));

        TextView title = new TextView(this);
        title.setText(label);
        title.setTextColor(COLOR_TEXT);
        title.setTextSize(18);
        row.addView(title, new LinearLayout.LayoutParams(0, dp(48), 1));

        EditText edit = new EditText(this);
        edit.setText(value);
        edit.setTextSize(15);
        edit.setSingleLine(true);
        edit.setGravity(Gravity.CENTER_VERTICAL | Gravity.RIGHT);
        edit.setTextColor(COLOR_MUTED);
        edit.setHintTextColor(Color.rgb(118, 118, 124));
        edit.setBackgroundColor(Color.TRANSPARENT);
        edit.setInputType(InputType.TYPE_CLASS_TEXT);
        row.addView(edit, new LinearLayout.LayoutParams(dp(98), dp(48)));

        View swatch = new View(this);
        swatch.setBackground(rounded(CardRenderer.parseColor(value, Color.WHITE), dp(14), Color.WHITE, dp(2)));
        LinearLayout.LayoutParams swatchParams = new LinearLayout.LayoutParams(dp(28), dp(28));
        swatchParams.setMargins(dp(10), 0, 0, 0);
        row.addView(swatch, swatchParams);
        View.OnClickListener openPicker = v -> showColorPicker(
                edit.getText().toString(),
                hex -> edit.setText(hex));
        swatch.setOnClickListener(openPicker);
        title.setOnClickListener(openPicker);
        edit.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                swatch.setBackground(rounded(CardRenderer.parseColor(s.toString(), Color.WHITE), dp(14), Color.WHITE, dp(2)));
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        });

        parent.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
        return edit;
    }

    private Button pillButton(String text, boolean compact) {
        Button button = new Button(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_TEXT);
        button.setTextSize(compact ? 18 : 20);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(COLOR_PANEL_2, dp(28), Color.rgb(86, 86, 92), dp(1)));
        return button;
    }

    private Button actionButton(String text) {
        Button button = new Button(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_BLUE);
        button.setTextSize(15);
        button.setGravity(Gravity.CENTER_VERTICAL | Gravity.LEFT);
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackgroundColor(Color.TRANSPARENT);
        return button;
    }

    private Button quietButton(String text) {
        Button button = new UiIcons.IconButton(this);
        normalizeButton(button);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_TEXT);
        button.setTextSize(15);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(COLOR_PANEL_2, dp(12)));
        return button;
    }

    private void normalizeButton(Button button) {
        button.setAllCaps(false);
        button.setMinWidth(0);
        button.setMinHeight(0);
        button.setMinimumWidth(0);
        button.setMinimumHeight(0);
        button.setIncludeFontPadding(false);
        button.setPadding(dp(10), 0, dp(10), 0);
        if (Build.VERSION.SDK_INT >= 21) {
            button.setStateListAnimator(null);
        }
    }

    private GradientDrawable rounded(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    private GradientDrawable rounded(int color, int radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = rounded(color, radius);
        drawable.setStroke(strokeWidth, strokeColor);
        return drawable;
    }

    private GradientDrawable topRounded(int color, int radius) {
        GradientDrawable drawable = rounded(color, 0);
        drawable.setCornerRadii(new float[]{radius, radius, radius, radius, 0, 0, 0, 0});
        return drawable;
    }

    private void addPageBackground(FrameLayout shell, MeQrProfile profile) {
        Bitmap bitmap = decodeBitmap(profile.backgroundPath);
        if (bitmap != null) {
            ImageView background = new ImageView(this);
            background.setImageBitmap(bitmap);
            background.setScaleType(ImageView.ScaleType.CENTER_CROP);
            background.setAlpha(1.0f);
            shell.addView(background, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        } else {
            View solid = new View(this);
            solid.setBackgroundColor(CardRenderer.parseColor(profile.backgroundColor, Color.WHITE));
            shell.addView(solid, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        }
        View wash = new View(this);
        wash.setBackgroundColor(Color.argb(14, 255, 255, 255));
        shell.addView(wash, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    }

    private Bitmap decodeBitmap(String path) {
        if (path == null || path.trim().isEmpty()) {
            return null;
        }
        return BitmapFactory.decodeFile(path);
    }

    private Bitmap initialBitmap(String name, int size, int backgroundColor, int textColor) {
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(backgroundColor);
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint);
        paint.setColor(textColor);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setTextSize(size * 0.48f);
        paint.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        String initial = name == null || name.trim().isEmpty() ? "M" : name.trim().substring(0, 1);
        Paint.FontMetrics metrics = paint.getFontMetrics();
        canvas.drawText(initial, size / 2f, size / 2f - (metrics.ascent + metrics.descent) / 2f, paint);
        return bitmap;
    }

    private Bitmap circleBitmap(Bitmap source, int size) {
        Bitmap scaled = Bitmap.createScaledBitmap(source, size, size, true);
        Bitmap output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(output);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setShader(new BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP));
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint);
        return output;
    }

    private int readableQrColor(int color) {
        int red = Color.red(color);
        int green = Color.green(color);
        int blue = Color.blue(color);
        double luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        int spread = Math.max(red, Math.max(green, blue)) - Math.min(red, Math.min(green, blue));
        if (luminance > 95 || spread < 42) {
            return Color.rgb(20, 20, 20);
        }
        return color;
    }

    private void styleSeek(SeekBar seekBar) {
        if (Build.VERSION.SDK_INT >= 21) {
            seekBar.setProgressTintList(ColorStateList.valueOf(COLOR_BLUE));
            seekBar.setThumbTintList(ColorStateList.valueOf(Color.WHITE));
            seekBar.setProgressBackgroundTintList(ColorStateList.valueOf(Color.rgb(82, 82, 88)));
        }
        seekBar.setPadding(dp(10), 0, dp(10), dp(8));
    }

    private void styleAlert(AlertDialog dialog) {
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(new ColorDrawable(COLOR_BG));
        }
        Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
        if (positive != null) {
            positive.setTextColor(COLOR_BLUE);
        }
        Button negative = dialog.getButton(AlertDialog.BUTTON_NEGATIVE);
        if (negative != null) {
            negative.setTextColor(COLOR_BLUE);
        }
    }

    private SeekBar.OnSeekBarChangeListener simpleSeek(SeekChange change) {
        return new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                change.onChange(progress);
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
            }
        };
    }

    private String value(EditText field, String fallback) {
        String value = field.getText().toString().trim();
        return value.isEmpty() ? fallback : value;
    }

    private String limitPassSubtitle(String value) {
        String normalized = value == null ? "" : value.replace("\r\n", "\n").replace('\r', '\n').replace('\n', ' ').trim();
        StringBuilder result = new StringBuilder();
        int units = 0;
        for (int offset = 0; offset < normalized.length();) {
            int codePoint = normalized.codePointAt(offset);
            int next = units + (codePoint <= 0x7f ? 1 : 2);
            if (next > 20) {
                break;
            }
            result.appendCodePoint(codePoint);
            units = next;
            offset += Character.charCount(codePoint);
        }
        return result.toString();
    }

    private void toast(String text) {
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private int statusTop() {
        int id = getResources().getIdentifier("status_bar_height", "dimen", "android");
        return id > 0 ? getResources().getDimensionPixelSize(id) : dp(24);
    }

    private int navigationBottom() {
        int id = getResources().getIdentifier("navigation_bar_height", "dimen", "android");
        return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
    }

    private interface SeekChange {
        void onChange(int value);
    }

    private interface ColorChoice {
        void onColor(String hex);
    }

    private static final class ActionSheetItem {
        final String icon;
        final String label;
        final boolean destructive;
        final Runnable action;

        ActionSheetItem(String icon, String label, boolean destructive, Runnable action) {
            this.icon = icon;
            this.label = label;
            this.destructive = destructive;
            this.action = action;
        }
    }

    private static final class EditSession {
        final MeQrProfile profile;
        final java.util.Set<String> recordedTagKeys = new java.util.HashSet<>();
        EditText name;
        EditText subtitle;
        EditText passSubtitle;
        EditText tags;
        TextView tagCount;
        Runnable onTagsChanged;
        boolean committingTags;
        String tagDraft = "";
        EditText textColor;
        EditText qrColor;
        EditText backgroundColor;
        EditText borderColor;
        ImageView preview;
        ImageView avatarPreview;
        LinearLayout qrItemsPanel;
        LinearLayout tagColorPanel;
        LinearLayout tagChips;
        LinearLayout tagSuggestions;
        int selectedQrIndex;
        boolean onboarding;

        EditSession(MeQrProfile profile) {
            this.profile = profile;
            for (String tag : profile.tags) recordedTagKeys.add(CardTagIndex.canonicalKey(tag));
        }
    }

    private enum CropMode {
        AVATAR,
        BACKGROUND,
        BANNER
    }

    private final class CropImageView extends View {
        private final Bitmap source;
        private final CropMode mode;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private float scale = 1f;
        private float minScale = 1f;
        private float offsetX = 0f;
        private float offsetY = 0f;
        private float lastX;
        private float lastY;
        private float lastDistance;
        private RectF cropRect = new RectF();

        CropImageView(Activity context, Bitmap source, CropMode mode) {
            super(context);
            this.source = source;
            this.mode = mode;
            setBackgroundColor(Color.BLACK);
        }

        @Override
        protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            float margin = dp(26);
            if (mode == CropMode.AVATAR) {
                float size = Math.min(w - margin * 2f, h * 0.62f);
                cropRect.set((w - size) / 2f, (h - size) / 2f, (w + size) / 2f, (h + size) / 2f);
            } else {
                float width = w - margin * 2f;
                float aspectRatio = mode == CropMode.BANNER ? 143f / 68f : 9f / 16f;
                float height = width / aspectRatio;
                if (height > h - margin * 2f) {
                    height = h - margin * 2f;
                    width = height * aspectRatio;
                }
                cropRect.set((w - width) / 2f, (h - height) / 2f, (w + width) / 2f, (h + height) / 2f);
            }
            minScale = Math.max(cropRect.width() / source.getWidth(), cropRect.height() / source.getHeight());
            scale = minScale;
            offsetX = cropRect.centerX();
            offsetY = cropRect.centerY();
            constrainOffsets();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            canvas.save();
            canvas.translate(offsetX, offsetY);
            canvas.scale(scale, scale);
            canvas.drawBitmap(source, -source.getWidth() / 2f, -source.getHeight() / 2f, paint);
            canvas.restore();

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(150, 0, 0, 0));
            canvas.drawRect(0, 0, getWidth(), cropRect.top, paint);
            canvas.drawRect(0, cropRect.bottom, getWidth(), getHeight(), paint);
            canvas.drawRect(0, cropRect.top, cropRect.left, cropRect.bottom, paint);
            canvas.drawRect(cropRect.right, cropRect.top, getWidth(), cropRect.bottom, paint);

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(2));
            paint.setColor(Color.WHITE);
            if (mode == CropMode.AVATAR) {
                canvas.drawOval(cropRect, paint);
            } else {
                canvas.drawRoundRect(cropRect, dp(18), dp(18), paint);
            }

            paint.setStyle(Paint.Style.FILL);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            if (event.getPointerCount() >= 2) {
                float distance = distance(event);
                if (event.getActionMasked() == MotionEvent.ACTION_POINTER_DOWN) {
                    lastDistance = distance;
                } else if (event.getActionMasked() == MotionEvent.ACTION_MOVE && lastDistance > 0f) {
                    float factor = distance / lastDistance;
                    scale = Math.max(minScale, Math.min(scale * factor, minScale * 5f));
                    lastDistance = distance;
                    constrainOffsets();
                    invalidate();
                } else if (event.getActionMasked() == MotionEvent.ACTION_POINTER_UP) {
                    int remainingIndex = event.getActionIndex() == 0 ? 1 : 0;
                    lastX = event.getX(remainingIndex);
                    lastY = event.getY(remainingIndex);
                    lastDistance = 0f;
                }
                return true;
            }

            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                lastX = event.getX();
                lastY = event.getY();
                return true;
            } else if (event.getActionMasked() == MotionEvent.ACTION_MOVE) {
                offsetX += event.getX() - lastX;
                offsetY += event.getY() - lastY;
                constrainOffsets();
                lastX = event.getX();
                lastY = event.getY();
                invalidate();
                return true;
            }
            return true;
        }

        Bitmap crop() {
            constrainOffsets();
            int outWidth = mode == CropMode.AVATAR ? 720 : mode == CropMode.BANNER ? 1430 : 1080;
            int outHeight = mode == CropMode.AVATAR ? 720 : mode == CropMode.BANNER ? 680 : 1920;
            Bitmap output = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(output);
            canvas.drawColor(Color.TRANSPARENT);
            float outScale = outWidth / cropRect.width();
            canvas.scale(outScale, outScale);
            canvas.translate(-cropRect.left, -cropRect.top);
            canvas.translate(offsetX, offsetY);
            canvas.scale(scale, scale);
            canvas.drawBitmap(source, -source.getWidth() / 2f, -source.getHeight() / 2f, paint);
            if (mode == CropMode.AVATAR) {
                Bitmap circleOutput = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.ARGB_8888);
                Canvas circleCanvas = new Canvas(circleOutput);
                Paint circlePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
                circlePaint.setShader(new BitmapShader(output, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP));
                circleCanvas.drawCircle(outWidth / 2f, outHeight / 2f, outWidth / 2f, circlePaint);
                return circleOutput;
            }
            return output;
        }

        private float distance(MotionEvent event) {
            float dx = event.getX(0) - event.getX(1);
            float dy = event.getY(0) - event.getY(1);
            return (float) Math.sqrt(dx * dx + dy * dy);
        }

        private void constrainOffsets() {
            if (cropRect.isEmpty()) {
                return;
            }
            float halfWidth = source.getWidth() * scale / 2f;
            float halfHeight = source.getHeight() * scale / 2f;
            float minX = cropRect.right - halfWidth;
            float maxX = cropRect.left + halfWidth;
            float minY = cropRect.bottom - halfHeight;
            float maxY = cropRect.top + halfHeight;
            offsetX = Math.max(minX, Math.min(offsetX, maxX));
            offsetY = Math.max(minY, Math.min(offsetY, maxY));
        }
    }
}
