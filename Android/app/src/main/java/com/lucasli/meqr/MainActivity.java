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
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class MainActivity extends Activity {
    private static final int PICK_AVATAR = 1001;
    private static final int PICK_BACKGROUND = 1002;
    private static final int REQUEST_WRITE_PHOTOS = 2001;
    private static final int COLOR_BG = Color.rgb(17, 17, 18);
    private static final int COLOR_PANEL = Color.rgb(43, 43, 46);
    private static final int COLOR_PANEL_2 = Color.rgb(55, 55, 59);
    private static final int COLOR_SURFACE = Color.rgb(31, 31, 34);
    private static final int COLOR_TEXT = Color.WHITE;
    private static final int COLOR_MUTED = Color.rgb(156, 156, 166);
    private static final int COLOR_SEPARATOR = Color.rgb(67, 67, 72);
    private static final int COLOR_BLUE = Color.rgb(10, 132, 255);

    private ProfileStore store;
    private I18n i18n;
    private final List<MeQrProfile> profiles = new ArrayList<>();
    private LinearLayout list;
    private MeQrProfile editingProfile;
    private EditSession editSession;
    private Bitmap pendingShareBitmap;
    private Bitmap pendingMeQrBitmap;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(COLOR_BG);
        getWindow().setNavigationBarColor(COLOR_BG);
        i18n = new I18n(this);
        store = new ProfileStore(this);
        profiles.clear();
        profiles.addAll(store.load());
        renderMain();
    }

    private void renderMain() {
        boolean immersive = !profiles.isEmpty();
        FrameLayout shell = new FrameLayout(this);
        shell.setBackgroundColor(immersive ? Color.WHITE : COLOR_BG);
        if (immersive) {
            getWindow().setStatusBarColor(Color.TRANSPARENT);
            getWindow().setNavigationBarColor(Color.TRANSPARENT);
            if (Build.VERSION.SDK_INT >= 23) {
                getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
            }
            addPageBackground(shell, profiles.get(0));
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
        subtitle.setText(profiles.isEmpty() ? i18n.t("emptyTitle") : profiles.size() + " profiles");
        subtitle.setTextSize(13);
        subtitle.setTextColor(immersive ? Color.argb(190, 0, 0, 0) : COLOR_MUTED);
        titleBlock.addView(subtitle);
        toolbar.addView(titleBlock, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        Button settings = immersive ? lightIconButton("⋯") : iconButton("⋯");
        settings.setContentDescription(i18n.t("settings"));
        settings.setOnClickListener(v -> showMainMenu());
        toolbar.addView(settings, new LinearLayout.LayoutParams(dp(58), dp(48)));
        root.addView(toolbar);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(dp(16), immersive ? dp(22) : dp(8), dp(16), dp(108));
        scroll.addView(list);
        root.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        shell.addView(root, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        Button fab = immersive ? lightFabButton("+") : fabButton("+");
        fab.setContentDescription(i18n.t("add"));
        fab.setOnClickListener(v -> showEditor(null));
        FrameLayout.LayoutParams fabParams = new FrameLayout.LayoutParams(dp(66), dp(66), Gravity.BOTTOM | Gravity.RIGHT);
        fabParams.setMargins(0, 0, dp(22), dp(28));
        shell.addView(fab, fabParams);

        setContentView(shell);
        renderList();
    }

    private void renderList() {
        list.removeAllViews();
        if (profiles.isEmpty()) {
            LinearLayout empty = new LinearLayout(this);
            empty.setOrientation(LinearLayout.VERTICAL);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(22), dp(54), dp(22), dp(54));
            empty.setBackground(rounded(COLOR_SURFACE, dp(28), Color.rgb(48, 48, 52), dp(1)));

            TextView icon = new TextView(this);
            icon.setText("▦");
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
            return;
        }

        for (int i = 0; i < profiles.size(); i++) {
            LinearLayout item = profileHero(profiles.get(i), i);
            LinearLayout.LayoutParams itemParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            itemParams.setMargins(0, 0, 0, dp(20));
            list.addView(item, itemParams);
        }
    }

    private LinearLayout profileHero(MeQrProfile profile, int index) {
        LinearLayout hero = new LinearLayout(this);
        hero.setOrientation(LinearLayout.VERTICAL);
        hero.setPadding(dp(18), dp(18), dp(18), dp(14));
        hero.setBackground(rounded(Color.argb(196, 255, 255, 255), dp(30), Color.argb(150, 255, 255, 255), dp(1)));
        hero.setElevation(dp(6));

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.HORIZONTAL);
        info.setGravity(Gravity.CENTER_VERTICAL);
        info.setPadding(0, 0, 0, dp(8));

        ImageView avatar = new ImageView(this);
        avatar.setScaleType(ImageView.ScaleType.CENTER_CROP);
        Bitmap avatarBitmap = decodeBitmap(profile.avatarPath);
        if (avatarBitmap != null) {
            avatar.setImageBitmap(circleBitmap(avatarBitmap, dp(74)));
        } else {
            avatar.setImageBitmap(initialBitmap(profile.name, dp(74), Color.argb(42, 0, 0, 0), Color.BLACK));
        }
        avatar.setBackground(rounded(Color.argb(40, 255, 255, 255), dp(22)));
        info.addView(avatar, new LinearLayout.LayoutParams(dp(74), dp(74)));

        LinearLayout texts = new LinearLayout(this);
        texts.setOrientation(LinearLayout.VERTICAL);
        texts.setPadding(dp(16), 0, 0, 0);
        TextView name = new TextView(this);
        name.setText(profile.name == null || profile.name.trim().isEmpty() ? i18n.t("appName") : profile.name.trim());
        name.setTextColor(Color.BLACK);
        name.setTextSize(24);
        name.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        texts.addView(name);
        if (profile.subtitle != null && !profile.subtitle.trim().isEmpty()) {
            TextView subtitle = new TextView(this);
            subtitle.setText(profile.subtitle.trim());
            subtitle.setTextColor(Color.argb(190, 0, 0, 0));
            subtitle.setTextSize(14);
            subtitle.setMaxLines(4);
            texts.addView(subtitle);
        }
        info.addView(texts, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        hero.addView(info);

        ImageView qr = new ImageView(this);
        qr.setScaleType(ImageView.ScaleType.FIT_CENTER);
        int qrColor = readableQrColor(CardRenderer.parseColor(profile.qrColor, Color.BLACK));
        qr.setImageBitmap(QrCodeGenerator.generateTransparent(profile.qrContent, qrColor, 900));
        LinearLayout.LayoutParams qrParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(310));
        qrParams.setMargins(0, dp(4), 0, dp(4));
        hero.addView(qr, qrParams);

        LinearLayout chips = new LinearLayout(this);
        chips.setOrientation(LinearLayout.HORIZONTAL);
        chips.setGravity(Gravity.CENTER_VERTICAL);
        chips.setPadding(0, dp(2), 0, dp(10));
        TextView platform = chip(profile.platformDisplayName(i18n), Color.argb(235, 64, 196, 184), Color.BLACK);
        chips.addView(platform);
        hero.addView(chips);

        return hero;
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
        cancel.setTextSize(28);
        cancel.setOnClickListener(v -> dialog.dismiss());
        topBar.addView(cancel, new LinearLayout.LayoutParams(dp(54), dp(48)));

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
        topBar.addView(save, new LinearLayout.LayoutParams(dp(96), dp(48)));
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
        editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720));
        previewPanel.addView(editSession.preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(360)));
        form.addView(previewPanel);

        form.addView(section(i18n.t("profileName")));
        LinearLayout infoPanel = panel();

        editSession.name = field(i18n.t("profileName"), editSession.profile.name, false);
        infoPanel.addView(editSession.name);
        infoPanel.addView(separator());

        editSession.subtitle = field(i18n.t("bio"), editSession.profile.subtitle, true);
        infoPanel.addView(editSession.subtitle);
        infoPanel.addView(separator());

        editSession.qrContent = field(i18n.t("qrContent"), editSession.profile.qrContent, true);
        infoPanel.addView(editSession.qrContent);

        form.addView(infoPanel);

        form.addView(section(i18n.t("platform")));
        LinearLayout platformPanel = panel();
        editSession.platformButton = rowButton(editSession.profile.platformDisplayName(i18n), "⌄");
        editSession.platformButton.setOnClickListener(v -> showPlatformPicker());
        platformPanel.addView(editSession.platformButton, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
        platformPanel.addView(separator());

        editSession.customPlatformName = field(i18n.t("customPlatform"), editSession.profile.customPlatformName, false);
        editSession.customPlatformName.setVisibility("custom".equals(editSession.profile.platform) ? View.VISIBLE : View.GONE);
        platformPanel.addView(editSession.customPlatformName);
        form.addView(platformPanel);

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
        if ("custom".equals(profile.platform) && profile.customPlatformName.isEmpty()) {
            profile.platform = PlatformNames.detect(profile.qrContent);
        }
        if ("custom".equals(profile.platform) && !profile.customPlatformName.isEmpty()) {
            String matched = PlatformNames.matchingName(profile.customPlatformName, i18n);
            if (matched != null) {
                profile.platform = matched;
                profile.customPlatformName = "";
            }
        }
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
        profile.qrContent = value(editSession.qrContent, "");
        profile.customPlatformName = value(editSession.customPlatformName, "");
        profile.textColor = value(editSession.textColor, "#111111");
        profile.qrColor = value(editSession.qrColor, "#111111");
        profile.backgroundColor = value(editSession.backgroundColor, "#FFFFFF");
        profile.borderColor = value(editSession.borderColor, "#111111");
    }

    private void updatePreview() {
        if (editSession == null || editSession.preview == null) {
            return;
        }
        applyEditFields(editSession.profile);
        editSession.preview.setImageBitmap(CardRenderer.render(editSession.profile, i18n, 720));
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
        editSession.qrContent.addTextChangedListener(watcher);
        editSession.customPlatformName.addTextChangedListener(watcher);
        editSession.textColor.addTextChangedListener(watcher);
        editSession.qrColor.addTextChangedListener(watcher);
        editSession.backgroundColor.addTextChangedListener(watcher);
        editSession.borderColor.addTextChangedListener(watcher);
    }

    private void showPlatformPicker() {
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
                        showPlatformPicker();
                        return;
                    }
                    editSession.profile.platform = PlatformNames.actualId(selected, i18n);
                    editSession.platformButton.setText(PlatformNames.displayName(editSession.profile.platform, i18n) + "   ⌄");
                    editSession.customPlatformName.setVisibility("custom".equals(editSession.profile.platform) ? View.VISIBLE : View.GONE);
                    updatePreview();
                })
                .show();
        styleAlert(dialog);
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
            toast(exception.getMessage());
        }
        renderList();
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
        if (resultCode != RESULT_OK || data == null || data.getData() == null || editSession == null) {
            return;
        }
        try {
            Uri uri = data.getData();
            Bitmap source;
            try (InputStream input = getContentResolver().openInputStream(uri)) {
                source = BitmapFactory.decodeStream(input);
            }
            if (source == null) {
                toast(i18n.t("saveFailed"));
                return;
            }
            showCropper(source, requestCode == PICK_AVATAR);
        } catch (IOException exception) {
            toast(exception.getMessage());
        }
    }

    private void showCropper(Bitmap source, boolean avatar) {
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
        title.setText(avatar ? i18n.t("avatar") : i18n.t("backgroundImage"));
        title.setTextColor(Color.WHITE);
        title.setTextSize(22);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setPadding(dp(14), 0, 0, 0);
        topBar.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        CropImageView cropView = new CropImageView(this, source, avatar);
        Button save = filledButton(i18n.t("save"));
        save.setOnClickListener(v -> {
            try {
                Bitmap cropped = cropView.crop();
                if (avatar) {
                    editSession.profile.avatarPath = store.saveBitmap(cropped, "avatar");
                } else {
                    editSession.profile.backgroundPath = store.saveBitmap(cropped, "background");
                }
                updatePreview();
                toast(i18n.t("done"));
                dialog.dismiss();
            } catch (IOException exception) {
                toast(exception.getMessage());
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

    private void shareProfile(MeQrProfile profile) {
        Bitmap bitmap = CardRenderer.render(profile, i18n, 1080);
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
        if (requestCode == REQUEST_WRITE_PHOTOS && pendingShareBitmap != null) {
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

    private void showMainMenu() {
        if (profiles.isEmpty()) {
            showSettings();
            return;
        }
        MeQrProfile profile = profiles.get(0);
        List<String> labels = new ArrayList<>();
        labels.add(i18n.t("meqrProfileCode"));
        labels.add(i18n.t("edit"));
        labels.add(i18n.t("share"));
        if (profiles.size() > 1) {
            labels.add("↑ " + i18n.t("moveUp"));
            labels.add("↓ " + i18n.t("moveDown"));
        }
        labels.add(i18n.t("delete"));
        labels.add(i18n.t("settings"));

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setItems(labels.toArray(new String[0]), (choiceDialog, which) -> {
                    String choice = labels.get(which);
                    if (choice.equals(i18n.t("meqrProfileCode"))) {
                        showMeQrCode(profile);
                    } else if (choice.equals(i18n.t("edit"))) {
                        showEditor(profile);
                    } else if (choice.equals(i18n.t("share"))) {
                        shareProfile(profile);
                    } else if (choice.startsWith("↑")) {
                        moveProfile(0, -1);
                    } else if (choice.startsWith("↓")) {
                        moveProfile(0, 1);
                    } else if (choice.equals(i18n.t("delete"))) {
                        confirmDelete(profile);
                    } else {
                        showSettings();
                    }
                })
                .show();
        styleAlert(dialog);
    }

    private void showSettings() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(12), dp(18), dp(12));
        root.setBackgroundColor(COLOR_BG);
        root.addView(heading(i18n.t("settings")));

        if (!profiles.isEmpty()) {
            Button meqr = actionButton(i18n.t("meqrProfileCode"));
            meqr.setOnClickListener(v -> showMeQrCode(profiles.get(0)));
            root.addView(meqr);
        }

        Button language = actionButton(i18n.t("language") + ": " + i18n.languageDisplayName(i18n.languageMode()));
        language.setOnClickListener(v -> showLanguagePicker());
        root.addView(language);

        TextView notice = new TextView(this);
        notice.setText(i18n.t("restartNotice"));
        notice.setTextColor(COLOR_MUTED);
        notice.setPadding(0, dp(4), 0, dp(10));
        root.addView(notice);

        Button about = actionButton(i18n.t("about"));
        about.setOnClickListener(v -> showAbout());
        root.addView(about);

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        styleAlert(dialog);
    }

    private void showLanguagePicker() {
        String[] modes = {I18n.SYSTEM, I18n.ZH_HANS, I18n.ZH_HANT_HK, I18n.ZH_HANT_TW, I18n.EN, I18n.JA};
        String[] labels = new String[modes.length];
        for (int i = 0; i < modes.length; i++) {
            labels[i] = i18n.languageDisplayName(modes[i]);
        }
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(i18n.t("language"))
                .setItems(labels, (choiceDialog, which) -> {
                    i18n.setLanguageMode(modes[which]);
                    renderMain();
                })
                .show();
        styleAlert(dialog);
    }

    private void showAbout() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(10), dp(18), dp(10));
        root.setBackgroundColor(COLOR_BG);
        TextView app = heading(i18n.t("appName"));
        app.setGravity(Gravity.CENTER);
        root.addView(app);

        TextView version = new TextView(this);
        version.setText(i18n.t("version") + " " + appVersionName());
        version.setTextColor(COLOR_MUTED);
        version.setGravity(Gravity.CENTER);
        version.setPadding(0, 0, 0, dp(12));
        root.addView(version);

        root.addView(linkButton(i18n.t("github"), "https://github.com/Rebirth39/MeQR"));
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

        AlertDialog dialog = new AlertDialog.Builder(this).setView(root).setPositiveButton(i18n.t("done"), null).show();
        styleAlert(dialog);
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
        String language = i18n.resolvedLanguage();
        if (I18n.ZH_HANS.equals(language) || I18n.ZH_HANT_HK.equals(language) || I18n.ZH_HANT_TW.equals(language)) {
            return "https://rebirth39.github.io/MeQR/privacy.html";
        }
        return "https://rebirth39.github.io/MeQR/privacy-en.html";
    }

    private void showMeQrCode(MeQrProfile profile) {
        String fallbackPayload;
        try {
            fallbackPayload = MeQrExchangeCodec.offlinePayload(profile, i18n);
        } catch (Exception exception) {
            toast(i18n.t("meqrCodeFailed"));
            return;
        }
        String fallbackCode = "meqr://profile?data=" + fallbackPayload;
        final Bitmap[] currentCode = new Bitmap[]{QrCodeGenerator.generate(fallbackCode, Color.BLACK, 960)};

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
                String hybridCode = MeQrExchangeCodec.hybridCode(remoteUrl, fallbackPayload);
                Bitmap onlineBitmap = QrCodeGenerator.generate(hybridCode, Color.BLACK, 960);
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
        copy.avatarPath = source.avatarPath;
        copy.backgroundPath = source.backgroundPath;
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
        view.setTextSize(19);
        view.setTextColor(COLOR_MUTED);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(dp(2), dp(26), 0, dp(10));
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
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_TEXT);
        button.setTextSize(22);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(COLOR_SURFACE, dp(24), Color.rgb(64, 64, 70), dp(1)));
        return button;
    }

    private Button fabButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(30);
        button.setGravity(Gravity.CENTER);
        button.setElevation(dp(8));
        button.setBackground(rounded(COLOR_BLUE, dp(33)));
        return button;
    }

    private Button lightFabButton(String text) {
        Button button = new Button(this);
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
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.BLACK);
        button.setTextSize(22);
        button.setGravity(Gravity.CENTER);
        button.setElevation(dp(4));
        button.setBackground(rounded(Color.argb(220, 255, 255, 255), dp(24), Color.argb(130, 255, 255, 255), dp(1)));
        return button;
    }

    private Button lightActionButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.rgb(20, 20, 20));
        button.setTextSize(15);
        button.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(Color.argb(190, 255, 255, 255), dp(16)));
        return button;
    }

    private Button filledButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setTextSize(17);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(COLOR_BLUE, dp(18)));
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
        panel.setPadding(dp(14), dp(10), dp(14), dp(10));
        panel.setBackground(rounded(COLOR_PANEL, dp(22)));
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
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_BLUE);
        button.setTextSize(18);
        button.setGravity(Gravity.CENTER);
        button.setBackgroundColor(Color.TRANSPARENT);
        return button;
    }

    private Button quietButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(COLOR_TEXT);
        button.setTextSize(16);
        button.setGravity(Gravity.CENTER);
        button.setBackground(rounded(COLOR_PANEL_2, dp(12)));
        return button;
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

    private interface SeekChange {
        void onChange(int value);
    }

    private static final class EditSession {
        final MeQrProfile profile;
        EditText name;
        EditText subtitle;
        EditText qrContent;
        EditText customPlatformName;
        EditText textColor;
        EditText qrColor;
        EditText backgroundColor;
        EditText borderColor;
        ImageView preview;
        Button platformButton;

        EditSession(MeQrProfile profile) {
            this.profile = profile;
        }
    }

    private final class CropImageView extends View {
        private final Bitmap source;
        private final boolean circle;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private float scale = 1f;
        private float minScale = 1f;
        private float offsetX = 0f;
        private float offsetY = 0f;
        private float lastX;
        private float lastY;
        private float lastDistance;
        private RectF cropRect = new RectF();

        CropImageView(Activity context, Bitmap source, boolean circle) {
            super(context);
            this.source = source;
            this.circle = circle;
            setBackgroundColor(Color.BLACK);
        }

        @Override
        protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            float margin = dp(26);
            if (circle) {
                float size = Math.min(w - margin * 2f, h * 0.62f);
                cropRect.set((w - size) / 2f, (h - size) / 2f, (w + size) / 2f, (h + size) / 2f);
            } else {
                float width = w - margin * 2f;
                float height = width * 16f / 9f;
                if (height > h - margin * 2f) {
                    height = h - margin * 2f;
                    width = height * 9f / 16f;
                }
                cropRect.set((w - width) / 2f, (h - height) / 2f, (w + width) / 2f, (h + height) / 2f);
            }
            minScale = Math.max(cropRect.width() / source.getWidth(), cropRect.height() / source.getHeight());
            scale = minScale;
            offsetX = cropRect.centerX();
            offsetY = cropRect.centerY();
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
            if (circle) {
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
                    invalidate();
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
                lastX = event.getX();
                lastY = event.getY();
                invalidate();
                return true;
            }
            return true;
        }

        Bitmap crop() {
            int outWidth = circle ? 720 : 1080;
            int outHeight = circle ? 720 : 1920;
            Bitmap output = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(output);
            canvas.drawColor(Color.TRANSPARENT);
            float outScale = outWidth / cropRect.width();
            canvas.scale(outScale, outScale);
            canvas.translate(-cropRect.left, -cropRect.top);
            canvas.translate(offsetX, offsetY);
            canvas.scale(scale, scale);
            canvas.drawBitmap(source, -source.getWidth() / 2f, -source.getHeight() / 2f, paint);
            if (circle) {
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
    }
}
