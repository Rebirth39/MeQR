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
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.google.zxing.Result;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

public final class MainActivity extends Activity {
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
    private final List<MeQrProfile> profiles = new ArrayList<>();
    private LinearLayout list;
    private int currentPage = 0;
    private MeQrProfile editingProfile;
    private EditSession editSession;
    private Bitmap pendingShareBitmap;
    private Bitmap pendingMeQrBitmap;
    private MeQrItem pendingQrItem;
    private EditText pendingQrField;
    private boolean scanningPhoto;
    private boolean croppingBanner;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(COLOR_BG);
        getWindow().setNavigationBarColor(COLOR_BG);
        i18n = new I18n(this);
        store = new ProfileStore(this);
        backupManager = new BackupManager(this);
        encounterStore = new EncounterStore(this);
        eventStore = new EventStore(this);
        updateManager = new AppUpdateManager(this, i18n);
        eventStore.refreshRemoteEvents();
        RemoteTagCatalog.refresh(false, null);
        profiles.clear();
        profiles.addAll(store.load());
        renderMain();
        getWindow().getDecorView().postDelayed(updateManager::checkAutomatically, 1600);
        if (profiles.isEmpty() && !getSharedPreferences("settings", MODE_PRIVATE).getBoolean(ONBOARDING_VERSION, false)) {
            getWindow().getDecorView().post(this::showOnboarding);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (updateManager != null) {
            updateManager.onResume();
        }
    }

    private void renderMain() {
        boolean immersive = !profiles.isEmpty();
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
        subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
        subtitle.setTextSize(13);
        subtitle.setTextColor(immersive ? Color.argb(190, 0, 0, 0) : COLOR_MUTED);
        titleBlock.addView(subtitle);
        toolbar.addView(titleBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        if (immersive) {
            MeQrProfile current = profiles.get(currentPage);
            Button shareMenu = lightIconButton("↗");
            shareMenu.setContentDescription(i18n.t("share"));
            shareMenu.setOnClickListener(v -> showShareMenu(current));
            toolbar.addView(shareMenu, new LinearLayout.LayoutParams(dp(44), dp(44)));

            Button cardMenu = lightIconButton("⋯");
            cardMenu.setContentDescription(i18n.t("settings"));
            cardMenu.setOnClickListener(v -> showCardMenu(current, currentPage));
            LinearLayout.LayoutParams cardMenuParams = new LinearLayout.LayoutParams(dp(44), dp(44));
            cardMenuParams.setMargins(dp(8), 0, 0, 0);
            toolbar.addView(cardMenu, cardMenuParams);
        } else {
            Button settings = iconButton("⋯");
            settings.setContentDescription(i18n.t("settings"));
            settings.setOnClickListener(v -> showSettings());
            toolbar.addView(settings, new LinearLayout.LayoutParams(dp(44), dp(44)));
        }
        root.addView(toolbar);

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
            renderEmptyState();
        }

        shell.addView(root, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        Button fab = immersive ? lightFabButton("+") : fabButton("+");
        fab.setContentDescription(i18n.t("add"));
        fab.setOnClickListener(v -> showEditor(null));
        FrameLayout.LayoutParams fabParams = new FrameLayout.LayoutParams(dp(66), dp(66), Gravity.BOTTOM | Gravity.RIGHT);
        fabParams.setMargins(0, 0, dp(22), dp(28));
        shell.addView(fab, fabParams);

        setContentView(shell);
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
        cancel.setOnClickListener(v -> dialog.dismiss());
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
            saveEdit();
            dialog.dismiss();
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
        templateControl.setPadding(dp(6), dp(6), dp(6), dp(6));
        Button standard = templateButton(i18n.t("standardTemplate"), "standard".equals(editSession.profile.template));
        Button rhodes = templateButton(i18n.t("rhodesTemplate"), "rhodes".equals(editSession.profile.template));
        standard.setOnClickListener(v -> {
            editSession.profile.template = "standard";
            styleTemplateButtons(standard, rhodes);
            updatePreview();
        });
        rhodes.setOnClickListener(v -> {
            editSession.profile.template = "rhodes";
            styleTemplateButtons(rhodes, standard);
            updatePreview();
        });
        templateControl.addView(standard, new LinearLayout.LayoutParams(0, dp(48), 1));
        LinearLayout.LayoutParams templateParams = new LinearLayout.LayoutParams(0, dp(48), 1);
        templateParams.setMargins(dp(6), 0, 0, 0);
        templateControl.addView(rhodes, templateParams);
        templatePanel.addView(templateControl);
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
        LinearLayout tagsPanel = panel();
        editSession.tags = field(i18n.t("tagsHint"), joinTags(editSession.profile.tags), true);
        editSession.tags.setMinLines(3);
        tagsPanel.addView(editSession.tags);
        tagsPanel.addView(separator());
        Button tagLibrary = actionButton("⌕  " + i18n.t("tagLibrary"));
        tagLibrary.setOnClickListener(v -> showTagLibrary());
        tagsPanel.addView(tagLibrary, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46)));
        form.addView(tagsPanel);

        form.addView(section(i18n.t("tagColors")));
        editSession.tagColorPanel = new LinearLayout(this);
        editSession.tagColorPanel.setOrientation(LinearLayout.VERTICAL);
        form.addView(editSession.tagColorPanel);
        editSession.tags.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                rebuildTagColorPanel();
            }
            @Override public void afterTextChanged(Editable s) { }
        });
        rebuildTagColorPanel();

        form.addView(section(i18n.t("avatar")));
        LinearLayout avatarPanel = panel();
        Button avatar = actionButton(editSession.profile.avatarPath.isEmpty() ? i18n.t("chooseImage") : i18n.t("removeImage") + " / " + i18n.t("chooseImage"));
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
        Button background = actionButton(editSession.profile.backgroundPath.isEmpty() ? i18n.t("chooseImage") : i18n.t("removeImage") + " / " + i18n.t("chooseImage"));
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
        Button banner = actionButton(editSession.profile.bannerPath.isEmpty() ? i18n.t("bannerImage") + " · " + i18n.t("chooseImage") : i18n.t("bannerImage") + " · " + i18n.t("removeImage") + " / " + i18n.t("chooseImage"));
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
        opacity.setMax(100);
        opacity.setProgress(Math.round(editSession.profile.cardOpacity * 100));
        opacity.setOnSeekBarChangeListener(simpleSeek(value -> {
            editSession.profile.cardOpacity = Math.max(0.25f, value / 100f);
            opacityValue.setText(i18n.t("opacity") + ": " + Math.round(editSession.profile.cardOpacity * 100) + "%");
            updatePreview();
        }));
        appearancePanel.addView(opacity);
        form.addView(appearancePanel);
        attachPreviewUpdates();

        dialog.setContentView(page);
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

    private void saveEdit() {
        MeQrProfile profile = editSession.profile;
        applyEditFields(profile);
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
        if (editingProfile == null) {
            profiles.add(profile);
        } else {
            int index = profiles.indexOf(editingProfile);
            if (index >= 0) {
                profiles.set(index, profile);
            }
        }
        persistAndRefresh();
    }

    private void applyEditFields(MeQrProfile profile) {
        profile.name = value(editSession.name, i18n.t("appName"));
        profile.subtitle = value(editSession.subtitle, "");
        profile.textColor = value(editSession.textColor, "#111111");
        profile.qrColor = value(editSession.qrColor, "#111111");
        profile.backgroundColor = value(editSession.backgroundColor, "#FFFFFF");
        profile.borderColor = value(editSession.borderColor, "#111111");
        profile.tags.clear();
        if (editSession.tags != null) {
            profile.tags.addAll(parseTags(editSession.tags.getText().toString()));
        }
        pruneTagOverrides(profile);
        profile.syncLegacyFields();
    }

    private void rebuildTagColorPanel() {
        if (editSession == null || editSession.tagColorPanel == null || editSession.tags == null) {
            return;
        }
        editSession.tagColorPanel.removeAllViews();
        List<String> tags = parseTags(editSession.tags.getText().toString());
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
        row.addView(label, new LinearLayout.LayoutParams(0, dp(48), 1));

        View swatch = new View(this);
        int[] colors = CardTagColorPalette.colorsFor(tag, editSession.profile.tagColorOverrides.get(tag));
        swatch.setBackground(tagColorDrawable(colors, dp(10)));
        LinearLayout.LayoutParams swatchParams = new LinearLayout.LayoutParams(dp(58), dp(24));
        swatchParams.setMargins(dp(8), 0, dp(8), 0);
        row.addView(swatch, swatchParams);

        boolean presetMulti = CardTagColorPalette.hasPresetMulti(tag);
        boolean presetSingle = CardTagColorPalette.isPresetColored(tag) && !presetMulti;
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

        parent.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
    }

    private void showTagLibrary() {
        if (editSession == null || editSession.tags == null) {
            return;
        }
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(16), dp(12), dp(16), dp(12));
        root.setBackgroundColor(COLOR_BG);

        EditText search = field(i18n.t("searchTags"), "", false);
        search.setBackground(rounded(COLOR_PANEL, dp(12), COLOR_SEPARATOR, dp(1)));
        root.addView(search, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));

        TextView hint = Ui.text(this, i18n.t("tagLibraryHint"), COLOR_MUTED, 12);
        hint.setPadding(dp(4), dp(9), dp(4), dp(8));
        root.addView(hint);

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
        Runnable refresh = () -> rebuildTagLibraryResults(results, search.getText().toString(), dialog);
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { refresh.run(); }
            @Override public void afterTextChanged(Editable s) { }
        });
        dialog.show();
        styleAlert(dialog);
        refresh.run();
        RemoteTagCatalog.refresh(true, refresh);
    }

    private void rebuildTagLibraryResults(LinearLayout results, String query, AlertDialog dialog) {
        results.removeAllViews();
        List<String> existing = parseTags(editSession.tags.getText().toString());
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
                    RemoteTagCatalog.refresh(true, () -> rebuildTagLibraryResults(results, query, dialog));
                    rebuildTagLibraryResults(results, query, dialog);
                });
            }
            results.addView(empty, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(84)));
            return;
        }
        for (int index = 0; index < matches.size(); index++) {
            String tag = matches.get(index);
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(dp(10), 0, dp(8), 0);
            row.setBackground(rounded(COLOR_PANEL, dp(11), COLOR_SEPARATOR, dp(1)));

            View swatch = new View(this);
            swatch.setBackground(tagColorDrawable(CardTagColorPalette.colorsFor(tag, null), dp(9)));
            row.addView(swatch, new LinearLayout.LayoutParams(dp(42), dp(20)));

            TextView name = Ui.boldText(this, tag, COLOR_TEXT, 15);
            name.setPadding(dp(12), 0, dp(8), 0);
            row.addView(name, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

            TextView add = Ui.boldText(this, "+", Ui.TEAL, 21);
            add.setGravity(Gravity.CENTER);
            row.addView(add, new LinearLayout.LayoutParams(dp(36), dp(36)));
            row.setOnClickListener(v -> {
                if (appendTag(tag)) {
                    rebuildTagLibraryResults(results, query, dialog);
                }
            });
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
            params.setMargins(0, 0, 0, dp(6));
            results.addView(row, params);
        }
    }

    private boolean appendTag(String tag) {
        List<String> tags = parseTags(editSession.tags.getText().toString());
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
        tags.add(MeQrProfile.normalizeTag(tag));
        editSession.tags.setText(joinTags(tags));
        editSession.tags.setSelection(editSession.tags.length());
        return true;
    }

    private void showTagColorEditor(String tag) {
        if (CardTagColorPalette.hasPresetMulti(tag)) {
            showPresetTagColorEditor(tag);
            return;
        }
        if (CardTagColorPalette.isPresetColored(tag)) {
            editSession.profile.tagColorOverrides.remove(tag);
            rebuildTagColorPanel();
            updatePreview();
            return;
        }

        String existingOverride = editSession.profile.tagColorOverrides.get(tag);
        boolean[] usePreset = new boolean[]{false};
        int[] initial = CardTagColorPalette.colorsFor(tag, existingOverride);
        List<String> colors = new ArrayList<>();
        for (int index = 0; index < Math.min(initial.length, 3); index++) {
            colors.add(CardTagColorPalette.hex(initial[index]));
        }

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(16), dp(8), dp(16), dp(8));
        root.setBackgroundColor(COLOR_BG);

        TextView preview = Ui.boldText(this, "# " + tag, Color.WHITE, 14);
        preview.setGravity(Gravity.CENTER);
        root.addView(preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(40)));

        LinearLayout colorRows = new LinearLayout(this);
        colorRows.setOrientation(LinearLayout.VERTICAL);
        root.addView(colorRows);

        rebuildTagColorEditorRows(colorRows, colors, tag, usePreset, preview);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("editTagColors"))
                .setView(root)
                .setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("save"), (choiceDialog, which) -> {
                    if (usePreset[0]) {
                        editSession.profile.tagColorOverrides.remove(tag);
                    } else {
                        String encoded = CardTagColorPalette.encodeColors(colors);
                        if (!encoded.isEmpty()) {
                            editSession.profile.tagColorOverrides.put(tag, encoded);
                        }
                    }
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
                                           boolean[] usePreset, TextView preview) {
        container.removeAllViews();
        int[] previewColors = usePreset[0]
                ? CardTagColorPalette.colorsFor(tag, null)
                : CardTagColorPalette.colorsFor(tag, CardTagColorPalette.encodeColors(colors));
        preview.setBackground(tagColorDrawable(previewColors, dp(12)));

        for (int index = 0; index < colors.size(); index++) {
            int colorIndex = index;
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);

            TextView label = Ui.text(this, i18n.t("color") + " " + (index + 1), COLOR_TEXT, 14);
            row.addView(label, new LinearLayout.LayoutParams(dp(72), dp(48)));

            EditText field = new EditText(this);
            field.setText(colors.get(index));
            field.setSingleLine(true);
            field.setTextColor(COLOR_TEXT);
            field.setTextSize(14);
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
                    rebuildTagColorEditorRows(container, colors, tag, usePreset, preview);
                });
                LinearLayout.LayoutParams removeParams = new LinearLayout.LayoutParams(dp(36), dp(36));
                removeParams.setMargins(dp(7), 0, 0, 0);
                row.addView(remove, removeParams);
            }

            field.addTextChangedListener(new TextWatcher() {
                @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) { }
                @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                    String normalized = CardTagColorPalette.normalizedHex(s.toString());
                    if (normalized != null) {
                        colors.set(colorIndex, normalized);
                        usePreset[0] = false;
                        swatch.setBackground(rounded(Color.parseColor(normalized), dp(10), Color.WHITE, dp(1)));
                        preview.setBackground(tagColorDrawable(CardTagColorPalette.colorsFor(tag,
                                CardTagColorPalette.encodeColors(colors)), dp(12)));
                    }
                }
                @Override public void afterTextChanged(Editable s) { }
            });
            container.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        }

        if (colors.size() < 3) {
            Button add = actionButton("＋  " + i18n.t("addColor"));
            add.setOnClickListener(v -> {
                colors.add(colors.isEmpty() ? "#39C5BB" : colors.get(colors.size() - 1));
                usePreset[0] = false;
                rebuildTagColorEditorRows(container, colors, tag, usePreset, preview);
            });
            container.addView(add, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(42)));
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

    private GradientDrawable tagColorDrawable(int[] colors, int radius) {
        int[] safeColors = colors == null || colors.length == 0 ? new int[]{Ui.TEAL} : colors;
        GradientDrawable drawable = safeColors.length == 1
                ? rounded(safeColors[0], radius, Color.argb(100, 255, 255, 255), dp(1))
                : new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, safeColors);
        drawable.setCornerRadius(radius);
        drawable.setStroke(dp(1), Color.argb(100, 255, 255, 255));
        return drawable;
    }

    private List<String> parseTags(String raw) {
        List<String> tags = new ArrayList<>();
        List<String> keys = new ArrayList<>();
        if (raw == null || raw.isEmpty()) {
            return tags;
        }
        for (String part : raw.split("[\\n\\r,，]+", -1)) {
            String tag = MeQrProfile.normalizeTag(part);
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

    private void pruneTagOverrides(MeQrProfile profile) {
        profile.tagColorOverrides.keySet().removeIf(tag -> !profile.tags.contains(tag));
    }

    private void updatePreview() {
        if (editSession == null || editSession.preview == null) {
            return;
        }
        applyEditFields(editSession.profile);
        editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720, editSession.selectedQrIndex));
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
        editSession.tags.addTextChangedListener(watcher);
        editSession.textColor.addTextChangedListener(watcher);
        editSession.qrColor.addTextChangedListener(watcher);
        editSession.backgroundColor.addTextChangedListener(watcher);
        editSession.borderColor.addTextChangedListener(watcher);
    }

    private void showPlatformPicker(MeQrItem item, Button platformButton, EditText customPlatformName) {
        List<String> ids = new ArrayList<>();
        List<String> labels = new ArrayList<>();
        addPlatformGroup(ids, labels, i18n.t("commonPlatforms"), PlatformNames.COMMON_IDS);
        addPlatformGroup(ids, labels, i18n.t("socialPlatforms"), PlatformNames.SOCIAL_IDS);
        addPlatformGroup(ids, labels, i18n.t("professionalPlatforms"), PlatformNames.PROFESSIONAL_IDS);
        ids.add("custom");
        labels.add(PlatformNames.displayName("custom", i18n));
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("platform"))
                .setItems(labels.toArray(new String[0]), (choiceDialog, which) -> {
                    String selected = ids.get(which);
                    if (selected.isEmpty()) {
                        showPlatformPicker(item, platformButton, customPlatformName);
                        return;
                    }
                    item.platform = PlatformNames.actualId(selected, i18n);
                    platformButton.setText(PlatformNames.displayName(item.platform, i18n) + "   ⌄");
                    customPlatformName.setVisibility("custom".equals(item.platform) ? View.VISIBLE : View.GONE);
                    updatePreview();
                })
                .show();
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
        } catch (IOException exception) {
            toast(i18n.t("saveFailed"));
        }
        renderMain();
    }

    private void chooseImage(int requestCode) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("image/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivityForResult(intent, requestCode);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null || data.getData() == null) {
            return;
        }
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
            Bitmap source;
            try (InputStream input = getContentResolver().openInputStream(uri)) {
                source = BitmapFactory.decodeStream(input);
            }
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

    private void confirmShareProfile(MeQrProfile profile) {
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("shareConfirmTitle"))
                .setMessage(i18n.t("shareConfirmBody"))
                .setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("continueShare"), (choiceDialog, which) -> shareProfile(profile))
                .show();
        styleAlert(dialog);
    }

    private void shareProfile(MeQrProfile profile) {
        MeQrProfile shareProfile = copy(profile);
        shareProfile.cardOpacity = 1f;
        Bitmap bitmap = CardRenderer.render(shareProfile, i18n, 1080);
        if (Build.VERSION.SDK_INT <= 28 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            pendingShareBitmap = bitmap;
            requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQUEST_WRITE_PHOTOS);
            return;
        }
        Uri uri = saveBitmapToGallery(bitmap);
        if (uri == null) {
            toast(i18n.t("saveFailed"));
            return;
        }
        toast(i18n.t("saved"));
        Intent share = new Intent(Intent.ACTION_SEND);
        share.setType("image/png");
        share.putExtra(Intent.EXTRA_STREAM, uri);
        share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(Intent.createChooser(share, i18n.t("share")));
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
        } else if (requestCode == REQUEST_WRITE_PHOTOS && pendingShareBitmap != null) {
            Bitmap bitmap = pendingShareBitmap;
            pendingShareBitmap = null;
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Uri uri = saveBitmapToGallery(bitmap);
                if (uri != null) {
                    toast(i18n.t("saved"));
                    Intent share = new Intent(Intent.ACTION_SEND);
                    share.setType("image/png");
                    share.putExtra(Intent.EXTRA_STREAM, uri);
                    share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(Intent.createChooser(share, i18n.t("share")));
                }
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

    // Top-right share menu (mirrors iOS trailing share menu), acts on the current card.
    private void showShareMenu(MeQrProfile profile) {
        List<ActionSheetItem> actions = new ArrayList<>();
        actions.add(new ActionSheetItem("↗", i18n.t("share"), false, () -> confirmShareProfile(profile)));
        actions.add(new ActionSheetItem("QR", i18n.t("meqrProfileCode"), false, () -> showMeQrCode(profile)));
        actions.add(new ActionSheetItem("▦", i18n.t("scanMeQr"), false, this::showScan));
        actions.add(new ActionSheetItem("◎", i18n.t("encounters"), false, this::showEncounters));
        actions.add(new ActionSheetItem("▤", i18n.t("events"), false, this::showEventCenter));
        showActionSheet(cardTitle(profile), actions);
    }

    // Top-right overflow menu (mirrors iOS leading menu), acts on the current card.
    private void showCardMenu(MeQrProfile profile, int index) {
        List<ActionSheetItem> actions = new ArrayList<>();
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
        TextView icon = new TextView(this);
        icon.setText(item.icon);
        icon.setTextColor(item.destructive ? Color.rgb(255, 116, 116) : Ui.SKY);
        icon.setTextSize(item.icon.length() > 1 ? 12 : 20);
        icon.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        icon.setGravity(Gravity.CENTER);
        icon.setIncludeFontPadding(false);
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

        TextView trailing = new TextView(this);
        trailing.setText("›");
        trailing.setTextColor(item.destructive ? Color.argb(160, 255, 116, 116) : COLOR_MUTED);
        trailing.setTextSize(24);
        trailing.setGravity(Gravity.CENTER);
        trailing.setIncludeFontPadding(false);
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

        TextView badge = Ui.boldText(this, "⚙", Ui.TEAL, 22);
        badge.setGravity(Gravity.CENTER);
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

        TextView icon = Ui.boldText(this, iconText, Ui.SKY, iconText.length() > 1 ? 12 : 19);
        icon.setGravity(Gravity.CENTER);
        icon.setBackground(rounded(Color.argb(30, 161, 209, 234), dp(12)));
        row.addView(icon, new LinearLayout.LayoutParams(dp(40), dp(40)));

        LinearLayout textBlock = new LinearLayout(this);
        textBlock.setOrientation(LinearLayout.VERTICAL);
        textBlock.setGravity(Gravity.CENTER_VERTICAL);
        textBlock.setPadding(dp(14), 0, dp(8), 0);
        TextView label = Ui.text(this, labelText, COLOR_TEXT, 16);
        label.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        label.setSingleLine(true);
        label.setEllipsize(android.text.TextUtils.TruncateAt.END);
        textBlock.addView(label);
        if (subtitleText != null && !subtitleText.trim().isEmpty()) {
            TextView subtitle = Ui.text(this, subtitleText, COLOR_MUTED, 12);
            subtitle.setSingleLine(true);
            subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
            subtitle.setPadding(0, dp(3), 0, 0);
            textBlock.addView(subtitle);
        }
        row.addView(textBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        TextView trailing = Ui.text(this, "›", COLOR_MUTED, 24);
        trailing.setGravity(Gravity.CENTER);
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
        editSession = new EditSession(draft);

        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackground(Ui.gradient(Color.rgb(20, 25, 31), COLOR_BG, 0));
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        page.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        renderOnboardingStep(dialog, content, 0);
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
        content.removeAllViews();
        if (step == 0) {
            renderOnboardingWelcome(dialog, content);
            return;
        }
        if (step == 6) {
            renderOnboardingComplete(dialog, content);
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
            LinearLayout identity = panel();
            editSession.name = field(i18n.t("profileName"), editSession.profile.name, false);
            editSession.subtitle = field(i18n.t("bio"), editSession.profile.subtitle, true);
            identity.addView(editSession.name);
            identity.addView(separator());
            identity.addView(editSession.subtitle);
            body.addView(identity);
            Button avatar = actionButton(i18n.t("chooseImage") + " · " + i18n.t("avatar"));
            avatar.setOnClickListener(v -> {
                syncOnboardingFields();
                chooseImage(PICK_AVATAR);
            });
            LinearLayout.LayoutParams avatarParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
            avatarParams.setMargins(0, dp(10), 0, 0);
            body.addView(avatar, avatarParams);
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
            TextWatcher watcher = directItemWatcher(item, qr, custom);
            qr.addTextChangedListener(watcher);
            custom.addTextChangedListener(watcher);
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
            LinearLayout templates = panel();
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(dp(6), dp(6), dp(6), dp(6));
            Button standard = templateButton(i18n.t("standardTemplate"), "standard".equals(editSession.profile.template));
            Button rhodes = templateButton(i18n.t("rhodesTemplate"), "rhodes".equals(editSession.profile.template));
            standard.setOnClickListener(v -> {
                editSession.profile.template = "standard";
                styleTemplateButtons(standard, rhodes);
            });
            rhodes.setOnClickListener(v -> {
                editSession.profile.template = "rhodes";
                styleTemplateButtons(rhodes, standard);
            });
            row.addView(standard, new LinearLayout.LayoutParams(0, dp(48), 1));
            LinearLayout.LayoutParams rhodesParams = new LinearLayout.LayoutParams(0, dp(48), 1);
            rhodesParams.setMargins(dp(6), 0, 0, 0);
            row.addView(rhodes, rhodesParams);
            templates.addView(row);
            body.addView(templates);
            LinearLayout colors = panel();
            editSession.textColor = addColorRow(colors, i18n.t("textColor"), editSession.profile.textColor);
            colors.addView(separator());
            editSession.qrColor = addColorRow(colors, i18n.t("qrColor"), editSession.profile.qrColor);
            colors.addView(separator());
            editSession.backgroundColor = addColorRow(colors, i18n.t("backgroundColor"), editSession.profile.backgroundColor);
            body.addView(colors);
            Button background = actionButton(i18n.t("chooseImage") + " · " + i18n.t("backgroundImage"));
            background.setOnClickListener(v -> {
                syncOnboardingFields();
                chooseImage(PICK_BACKGROUND);
            });
            LinearLayout.LayoutParams backgroundParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52));
            backgroundParams.setMargins(0, dp(10), 0, 0);
            body.addView(background, backgroundParams);
        } else if (step == 4) {
            LinearLayout tagsPanel = panel();
            editSession.tags = field(i18n.t("tagsHint"), joinTags(editSession.profile.tags), true);
            editSession.tags.setMinLines(5);
            tagsPanel.addView(editSession.tags);
            tagsPanel.addView(separator());
            Button tagLibrary = actionButton("⌕  " + i18n.t("tagLibrary"));
            tagLibrary.setOnClickListener(v -> showTagLibrary());
            tagsPanel.addView(tagLibrary, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(46)));
            body.addView(tagsPanel);
        } else {
            editSession.preview = new ImageView(this);
            editSession.preview.setAdjustViewBounds(true);
            editSession.preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
            editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 900));
            body.addView(editSession.preview);
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
        sample.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720));
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
        Button start = filledButton(i18n.t("setupStart") + "  →");
        start.setOnClickListener(v -> renderOnboardingStep(dialog, content, 1));
        body.addView(start, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
        Button later = quietButton(i18n.t("cancel"));
        later.setOnClickListener(v -> dialog.dismiss());
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
        Button enter = filledButton(i18n.t("setupEnter") + "  →");
        enter.setOnClickListener(v -> {
            dialog.dismiss();
            renderMain();
        });
        body.addView(enter, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
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
        getSharedPreferences("settings", MODE_PRIVATE).edit().putBoolean(ONBOARDING_VERSION, true).apply();
        return true;
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
        if (editSession.textColor != null) {
            editSession.profile.textColor = value(editSession.textColor, editSession.profile.textColor);
        }
        if (editSession.qrColor != null) {
            editSession.profile.qrColor = value(editSession.qrColor, editSession.profile.qrColor);
        }
        if (editSession.backgroundColor != null) {
            editSession.profile.backgroundColor = value(editSession.backgroundColor, editSession.profile.backgroundColor);
        }
        if (editSession.tags != null) {
            editSession.profile.tags.clear();
            editSession.profile.tags.addAll(parseTags(editSession.tags.getText().toString()));
            pruneTagOverrides(editSession.profile);
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
                TextView check = Ui.boldText(this, "✓", Ui.TEAL, 18);
                check.setGravity(Gravity.CENTER);
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

        root.addView(linkButton(i18n.t("website"), "https://meqrcode.cn/"));
        root.addView(linkButton(i18n.t("privacy"), privacyUrl()));
        root.addView(linkButton(i18n.t("email") + ": lucas_and_miku@icloud.com", "mailto:lucas_and_miku@icloud.com"));
        root.addView(linkButton("QID: Rebirth39", "https://qm.qq.com/q/ErpPGQuaAi"));

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
        String fallbackPayload;
        try {
            fallbackPayload = MeQrExchangeCodec.offlinePayload(profile, i18n);
        } catch (Exception exception) {
            toast(i18n.t("meqrCodeFailed"));
            return;
        }
        String fallbackCode = QrCodeGenerator.paddedForColorLayer(
                "meqr://profile?data=" + fallbackPayload,
                800
        );
        byte[] fallbackAvatar = MeQrExchangeCodec.colorLayerAvatarJpeg(
                profile,
                QrCodeGenerator.colorLayerPayloadCapacity(fallbackCode)
        );
        final Bitmap[] currentCode = new Bitmap[]{QrCodeGenerator.generateColorLayered(fallbackCode, fallbackAvatar, 960)};

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(20), dp(14), dp(20), dp(12));
        root.setBackgroundColor(COLOR_BG);

        ImageView avatar = new ImageView(this);
        Bitmap avatarBitmap = decodeBitmap(profile.avatarPath);
        if (avatarBitmap != null) {
            avatar.setImageBitmap(circleBitmap(avatarBitmap, dp(72)));
        } else {
            avatar.setImageBitmap(initialBitmap(profile.name, dp(72), Color.rgb(62, 62, 68), Color.WHITE));
        }
        root.addView(avatar, new LinearLayout.LayoutParams(dp(72), dp(72)));

        TextView name = heading(profile.name == null || profile.name.trim().isEmpty() ? i18n.t("appName") : profile.name.trim());
        name.setGravity(Gravity.CENTER);
        name.setTextSize(21);
        root.addView(name);

        ImageView qr = new ImageView(this);
        qr.setImageBitmap(currentCode[0]);
        qr.setBackground(rounded(Color.WHITE, dp(24)));
        qr.setPadding(dp(14), dp(14), dp(14), dp(14));
        LinearLayout.LayoutParams qrParams = new LinearLayout.LayoutParams(dp(290), dp(290));
        qrParams.setMargins(0, dp(8), 0, dp(14));
        root.addView(qr, qrParams);

        TextView mode = new TextView(this);
        mode.setText(i18n.t("meqrPreparingOnline"));
        mode.setTextColor(COLOR_MUTED);
        mode.setTextSize(13);
        mode.setGravity(Gravity.CENTER);
        mode.setPadding(dp(8), 0, dp(8), dp(8));
        root.addView(mode);

        TextView hint = new TextView(this);
        hint.setText(i18n.t("meqrCodeHint"));
        hint.setTextColor(COLOR_MUTED);
        hint.setTextSize(14);
        hint.setGravity(Gravity.CENTER);
        hint.setPadding(dp(8), 0, dp(8), dp(14));
        root.addView(hint);

        Button save = filledButton(i18n.t("saveMeQrCode"));
        save.setOnClickListener(v -> saveMeQrBitmap(currentCode[0]));
        root.addView(save, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        styleAlert(dialog);

        new Thread(() -> {
            try {
                String remoteUrl = MeQrRemoteService.uploadProfile(MeQrExchangeCodec.onlineProfile(profile, i18n));
                String hybridCode = QrCodeGenerator.paddedForColorLayer(
                        MeQrExchangeCodec.hybridCode(remoteUrl, fallbackPayload),
                        800
                );
                byte[] onlineAvatar = MeQrExchangeCodec.colorLayerAvatarJpeg(
                        profile,
                        QrCodeGenerator.colorLayerPayloadCapacity(hybridCode)
                );
                Bitmap onlineBitmap = QrCodeGenerator.generateColorLayered(hybridCode, onlineAvatar, 960);
                runOnUiThread(() -> {
                    currentCode[0] = onlineBitmap;
                    qr.setImageBitmap(onlineBitmap);
                    mode.setText(i18n.t("meqrOnlineReady"));
                });
            } catch (Exception exception) {
                runOnUiThread(() -> mode.setText(i18n.t("meqrOnlineFallback")));
            }
        }).start();
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
                scanningPhoto = true;
                chooseImage(PICK_SCAN_QR);
            }
        }).show();
    }

    private void handleMeQrPayload(String payload) {
        handleMeQrPayload(payload, null);
    }

    private void handleMeQrPayload(String payload, byte[] colorAvatarJpeg) {
        try {
            MeQrExchangeProfile profile = MeQrExchangeCodec.decode(payload);
            showEncounterPreview(applyColorAvatar(profile, colorAvatarJpeg));
            return;
        } catch (Exception ignored) {
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
        MeQrExchangeProfile fallback = MeQrExchangeCodec.offlineFallback(payload);
        if (fallback != null) {
            showEncounterPreview(applyColorAvatar(fallback, colorAvatarJpeg));
        } else {
            toast(i18n.t("notMeQrCode"));
        }
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
        if (profile.subtitle != null && !profile.subtitle.trim().isEmpty()) {
            TextView subtitle = new TextView(this);
            subtitle.setText(profile.subtitle.trim());
            subtitle.setTextSize(14);
            subtitle.setTextColor(COLOR_MUTED);
            subtitle.setPadding(0, dp(4), 0, 0);
            nameBlock.addView(subtitle);
        }
        header.addView(nameBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        root.addView(header);

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
            encounterStore.add(profile, eventStore.activeEvent());
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
            open.setOnClickListener(v -> {
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(content)));
                } catch (Exception ignored) {
                }
            });
            row.addView(open, new LinearLayout.LayoutParams(dp(52), dp(48)));
        }
        return row;
    }

    private boolean canOpenLink(String content) {
        if (content == null || content.isEmpty()) {
            return false;
        }
        try {
            String scheme = new java.net.URI(content).getScheme();
            if (scheme == null) {
                return false;
            }
            String lower = scheme.toLowerCase(Locale.US);
            return lower.equals("http") || lower.equals("https") || lower.equals("qq") || lower.equals("mqq")
                    || lower.equals("weixin") || lower.equals("wechat") || lower.equals("line")
                    || lower.equals("discord") || lower.equals("reddit");
        } catch (Exception exception) {
            return false;
        }
    }

    private void showEncounters() {
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
        root.addView(delete, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)));

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
        final boolean[] state = {initial};
        Button toggle = pillButton(state[0] ? "✓ " + i18n.t("on") : i18n.t("off"), true);
        toggle.setTextSize(14);
        toggle.setOnClickListener(v -> {
            state[0] = !state[0];
            toggle.setText(state[0] ? "✓ " + i18n.t("on") : i18n.t("off"));
            onChange.accept(state[0]);
        });
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
            byte[] bytes = android.util.Base64.decode(base64, android.util.Base64.DEFAULT);
            return BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
        } catch (Exception exception) {
            return null;
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
        copy.template = source.template;
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
        Button button = new Button(this);
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
        Button button = new Button(this);
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
        Button button = new Button(this);
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
        Button button = new Button(this);
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
        Button button = new Button(this);
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
        button.setText(leading + "   " + trailing);
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
        Button button = new Button(this);
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
        EditText name;
        EditText subtitle;
        EditText tags;
        EditText textColor;
        EditText qrColor;
        EditText backgroundColor;
        EditText borderColor;
        ImageView preview;
        LinearLayout qrItemsPanel;
        LinearLayout tagColorPanel;
        int selectedQrIndex;

        EditSession(MeQrProfile profile) {
            this.profile = profile;
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
