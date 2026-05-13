package tech.power.RNBraintreeDropIn;

import android.content.DialogInterface;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.InputFilter;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.DialogFragment;

import com.braintreepayments.api.BraintreeClient;
import com.braintreepayments.api.Card;
import com.braintreepayments.api.CardClient;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableMap;

public class RNBTCardFormFragment extends DialogFragment {

    static Promise sPromise = null;
    static String sClientToken = null;
    static boolean sDarkTheme = false;

    private EditText etCardNumber;
    private EditText etExpiry;
    private EditText etCvv;
    private TextView btnSubmit;
    private ProgressBar progressBar;
    private ImageView cardNetworkIcon;

    private boolean cardFormatting = false;
    private boolean expiryFormatting = false;
    private String currentCardBrand = "";

    public static RNBTCardFormFragment newInstance(String clientToken, boolean darkTheme, Promise promise) {
        sPromise = promise;
        sClientToken = clientToken;
        sDarkTheme = darkTheme;
        return new RNBTCardFormFragment();
    }

    private int dp(float dp) {
        return Math.round(dp * requireContext().getResources().getDisplayMetrics().density);
    }

    private int bgColor()        { return sDarkTheme ? 0xFF1C1C1E : 0xFFF2F2F7; }
    private int containerColor() { return sDarkTheme ? 0xFF2C2C2E : 0xFFFFFFFF; }
    private int textColor()      { return sDarkTheme ? 0xFFFFFFFF : 0xFF000000; }
    private int hintColor()      { return sDarkTheme ? 0xFF98989D : 0xFF6C6C70; }
    private int separatorColor() { return sDarkTheme ? 0xFF3A3A3C : 0xFFE5E5EA; }
    private static final int ACCENT = 0xFF007AFF;

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setStyle(STYLE_NORMAL, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        LinearLayout root = new LinearLayout(requireContext());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(bgColor());
        root.setLayoutParams(new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        root.addView(buildNavBar());

        LinearLayout content = new LinearLayout(requireContext());
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(16), dp(20), dp(16), dp(24));
        content.setLayoutParams(new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        content.addView(buildFormContainer());
        content.addView(buildSpacing(dp(16)));
        content.addView(buildSubmitButton());

        root.addView(content);
        return root;
    }

    private View buildNavBar() {
        FrameLayout navBar = new FrameLayout(requireContext());
        navBar.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));
        navBar.setBackgroundColor(containerColor());

        View border = new View(requireContext());
        border.setBackgroundColor(separatorColor());
        FrameLayout.LayoutParams borderParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1);
        borderParams.gravity = Gravity.BOTTOM;
        border.setLayoutParams(borderParams);

        TextView title = new TextView(requireContext());
        title.setText("Add Card");
        title.setTextColor(textColor());
        title.setTextSize(17);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.CENTER);
        title.setLayoutParams(new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        TextView cancelBtn = new TextView(requireContext());
        cancelBtn.setText("Cancel");
        cancelBtn.setTextColor(ACCENT);
        cancelBtn.setTextSize(17);
        cancelBtn.setPadding(dp(16), 0, dp(16), 0);
        cancelBtn.setGravity(Gravity.CENTER_VERTICAL);
        FrameLayout.LayoutParams cancelParams = new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT);
        cancelParams.gravity = Gravity.START | Gravity.CENTER_VERTICAL;
        cancelBtn.setLayoutParams(cancelParams);
        cancelBtn.setOnClickListener(v -> {
            Promise p = sPromise;
            sPromise = null;
            dismiss();
            if (p != null) p.reject("USER_CANCELLATION", "The user cancelled");
        });

        navBar.addView(border);
        navBar.addView(title);
        navBar.addView(cancelBtn);
        return navBar;
    }

    private View buildFormContainer() {
        LinearLayout container = new LinearLayout(requireContext());
        container.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(containerColor());
        bg.setCornerRadius(dp(12));
        container.setBackground(bg);
        container.setClipToOutline(true);
        container.setLayoutParams(new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        // Card number row
        LinearLayout cardRow = new LinearLayout(requireContext());
        cardRow.setOrientation(LinearLayout.HORIZONTAL);
        cardRow.setGravity(Gravity.CENTER_VERTICAL);
        cardRow.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        cardRow.setPadding(dp(16), 0, dp(12), 0);

        etCardNumber = buildField("Card Number", InputType.TYPE_CLASS_NUMBER, 19);
        etCardNumber.addTextChangedListener(cardNumberWatcher);
        cardRow.addView(etCardNumber);

        cardNetworkIcon = new ImageView(requireContext());
        cardNetworkIcon.setScaleType(ImageView.ScaleType.FIT_CENTER);
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(dp(58), dp(30));
        iconParams.setMargins(0, 0, dp(4), 0);
        cardNetworkIcon.setLayoutParams(iconParams);
        cardNetworkIcon.setVisibility(View.GONE);
        cardRow.addView(cardNetworkIcon);

        container.addView(cardRow);
        container.addView(buildHSeparator());

        // Expiry + CVV row
        LinearLayout expiryRow = new LinearLayout(requireContext());
        expiryRow.setOrientation(LinearLayout.HORIZONTAL);
        expiryRow.setGravity(Gravity.CENTER_VERTICAL);
        expiryRow.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));

        etExpiry = buildField("MM / YY", InputType.TYPE_CLASS_NUMBER, 7);
        LinearLayout.LayoutParams expiryParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f);
        expiryParams.leftMargin = dp(16);
        etExpiry.setLayoutParams(expiryParams);
        etExpiry.addTextChangedListener(expiryWatcher);

        View vSep = new View(requireContext());
        vSep.setBackgroundColor(separatorColor());
        LinearLayout.LayoutParams vSepParams = new LinearLayout.LayoutParams(1, dp(32));
        vSep.setLayoutParams(vSepParams);

        etCvv = buildField("CVV", InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD, 4);
        LinearLayout.LayoutParams cvvParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f);
        cvvParams.leftMargin = dp(12);
        cvvParams.rightMargin = dp(16);
        etCvv.setLayoutParams(cvvParams);

        expiryRow.addView(etExpiry);
        expiryRow.addView(vSep);
        expiryRow.addView(etCvv);
        container.addView(expiryRow);

        return container;
    }

    private EditText buildField(String hint, int inputType, int maxLen) {
        EditText et = new EditText(requireContext());
        et.setHint(hint);
        et.setHintTextColor(hintColor());
        et.setTextColor(textColor());
        et.setInputType(inputType);
        et.setFilters(new InputFilter[]{new InputFilter.LengthFilter(maxLen)});
        et.setBackground(null);
        et.setTextSize(16);
        et.setSingleLine(true);
        et.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f));
        return et;
    }

    private View buildHSeparator() {
        View sep = new View(requireContext());
        sep.setBackgroundColor(separatorColor());
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1);
        p.leftMargin = dp(16);
        sep.setLayoutParams(p);
        return sep;
    }

    private View buildSpacing(int height) {
        View v = new View(requireContext());
        v.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height));
        return v;
    }

    private View buildSubmitButton() {
        FrameLayout frame = new FrameLayout(requireContext());
        frame.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));

        GradientDrawable btnBg = new GradientDrawable();
        btnBg.setColor(sDarkTheme ? Color.WHITE : Color.BLACK);
        btnBg.setCornerRadius(dp(14));

        btnSubmit = new TextView(requireContext());
        btnSubmit.setText("Add Card");
        btnSubmit.setTextColor(sDarkTheme ? Color.BLACK : Color.WHITE);
        btnSubmit.setTextSize(17);
        btnSubmit.setTypeface(Typeface.DEFAULT_BOLD);
        btnSubmit.setGravity(Gravity.CENTER);
        btnSubmit.setBackground(btnBg);
        btnSubmit.setLayoutParams(new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        btnSubmit.setOnClickListener(v -> submitCard());

        progressBar = new ProgressBar(requireContext(), null, android.R.attr.progressBarStyleSmall);
        progressBar.getIndeterminateDrawable().setColorFilter(
            new PorterDuffColorFilter(sDarkTheme ? Color.BLACK : Color.WHITE, PorterDuff.Mode.SRC_IN));
        FrameLayout.LayoutParams pbParams = new FrameLayout.LayoutParams(dp(24), dp(24));
        pbParams.gravity = Gravity.CENTER;
        progressBar.setLayoutParams(pbParams);
        progressBar.setVisibility(View.GONE);

        frame.addView(btnSubmit);
        frame.addView(progressBar);
        return frame;
    }

    private String detectCardBrand(String digits) {
        if (digits.startsWith("34") || digits.startsWith("37")) return "AMEX";
        if (digits.startsWith("4")) return "VISA";
        if (digits.length() >= 4) {
            try {
                int p4 = Integer.parseInt(digits.substring(0, 4));
                if (p4 >= 2221 && p4 <= 2720) return "MC";
                if (p4 >= 3000 && p4 <= 3059) return "DINERS";
            } catch (NumberFormatException ignored) {}
        }
        if (digits.length() >= 2) {
            try {
                int p2 = Integer.parseInt(digits.substring(0, 2));
                if (p2 >= 51 && p2 <= 55) return "MC";
                if (p2 == 35) return "JCB";
                if (p2 == 36 || p2 == 38) return "DINERS";
            } catch (NumberFormatException ignored) {}
        }
        if (digits.startsWith("6011") || digits.startsWith("65")) return "DISC";
        return "";
    }

    private String cardBrandImageName(String brand) {
        switch (brand) {
            case "VISA":   return "visa";
            case "MC":     return "mastercard";
            case "AMEX":   return "amex";
            case "DISC":   return "discover";
            case "JCB":    return "jcb";
            case "DINERS": return "diners";
            default:       return null;
        }
    }

    private final TextWatcher cardNumberWatcher = new TextWatcher() {
        @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
        @Override public void afterTextChanged(Editable s) {}

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
            if (cardFormatting) return;
            cardFormatting = true;

            String raw = s.toString().replace(" ", "");
            String brand = raw.length() > 0 ? detectCardBrand(raw) : "";

            int[] groups = "AMEX".equals(brand) ? new int[]{4, 6, 5} : new int[]{4, 4, 4, 4};
            int maxDigits = "AMEX".equals(brand) ? 15 : 16;
            if (raw.length() > maxDigits) raw = raw.substring(0, maxDigits);

            StringBuilder formatted = new StringBuilder();
            int idx = 0;
            for (int g = 0; g < groups.length && idx < raw.length(); g++) {
                if (g > 0) formatted.append(" ");
                int end = Math.min(idx + groups[g], raw.length());
                formatted.append(raw, idx, end);
                idx += groups[g];
            }

            int maxFormatted = maxDigits + groups.length - 1;
            etCardNumber.setFilters(new InputFilter[]{new InputFilter.LengthFilter(maxFormatted)});
            etCardNumber.setText(formatted.toString());
            etCardNumber.setSelection(formatted.length());

            if (!brand.equals(currentCardBrand)) {
                currentCardBrand = brand;
                String imageName = cardBrandImageName(brand);
                int resId = imageName != null ? requireContext().getResources().getIdentifier(
                        imageName, "drawable", requireContext().getPackageName()) : 0;
                if (resId != 0) {
                    cardNetworkIcon.setImageResource(resId);
                    cardNetworkIcon.setVisibility(View.VISIBLE);
                } else {
                    cardNetworkIcon.setVisibility(View.GONE);
                }
            }
            cardFormatting = false;
        }
    };

    private final TextWatcher expiryWatcher = new TextWatcher() {
        @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
        @Override public void afterTextChanged(Editable s) {}

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
            if (expiryFormatting) return;
            expiryFormatting = true;
            String digits = s.toString().replaceAll("[^0-9]", "");
            String formatted = digits.length() >= 2 ? digits.substring(0, 2) + " / " + digits.substring(2) : digits;
            etExpiry.setText(formatted);
            etExpiry.setSelection(formatted.length());
            expiryFormatting = false;
        }
    };

    private void submitCard() {
        String rawNumber = etCardNumber.getText().toString().replace(" ", "");
        String expiryDigits = etExpiry.getText().toString().replaceAll("[^0-9]", "");
        String cvv = etCvv.getText() != null ? etCvv.getText().toString().trim() : "";

        if (rawNumber.length() < 13) { etCardNumber.setError("Enter a valid card number"); return; }
        if (expiryDigits.length() < 4) { etExpiry.setError("Enter expiry MM/YY"); return; }
        if (cvv.length() < 3) { etCvv.setError("Enter CVV"); return; }

        String expiryMonth = expiryDigits.substring(0, 2);
        String expiryYear = "20" + expiryDigits.substring(2);

        btnSubmit.setText("");
        progressBar.setVisibility(View.VISIBLE);
        btnSubmit.setEnabled(false);

        BraintreeClient braintreeClient = new BraintreeClient(requireContext(), sClientToken);
        CardClient cardClient = new CardClient(braintreeClient);

        Card card = new Card();
        card.setNumber(rawNumber);
        card.setExpirationMonth(expiryMonth);
        card.setExpirationYear(expiryYear);
        card.setCvv(cvv);

        cardClient.tokenize(card, (cardNonce, error) -> {
            if (getActivity() == null) return;
            getActivity().runOnUiThread(() -> {
                btnSubmit.setText("Add Card");
                progressBar.setVisibility(View.GONE);
                btnSubmit.setEnabled(true);

                Promise p = sPromise;
                sPromise = null;

                if (error != null) {
                    if (p != null) p.reject("TOKENIZE_ERROR", error.getMessage());
                    return;
                }
                if (cardNonce == null) {
                    if (p != null) p.reject("NO_CARD_NONCE", "Card nonce is null");
                    return;
                }

                dismiss();

                if (p != null) {
                    WritableMap jsResult = Arguments.createMap();
                    jsResult.putString("nonce", cardNonce.getString());
                    jsResult.putString("type", "Card");
                    jsResult.putString("description", "Ending in " + cardNonce.getLastFour());
                    jsResult.putBoolean("isDefault", false);
                    jsResult.putString("deviceData", "");
                    p.resolve(jsResult);
                }
            });
        });
    }

    @Override
    public void onCancel(@NonNull DialogInterface dialog) {
        super.onCancel(dialog);
        Promise p = sPromise;
        sPromise = null;
        if (p != null) p.reject("USER_CANCELLATION", "The user cancelled");
    }

    @Override
    public void onResume() {
        super.onResume();
        if (getDialog() != null && getDialog().getWindow() != null) {
            Window window = getDialog().getWindow();
            window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        }
    }
}
