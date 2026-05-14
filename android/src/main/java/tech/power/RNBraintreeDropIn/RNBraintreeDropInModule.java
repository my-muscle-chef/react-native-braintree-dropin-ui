package tech.power.RNBraintreeDropIn;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;

import androidx.activity.ComponentActivity;
import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentActivity;

import com.braintreepayments.api.Card;
import com.braintreepayments.api.CardClient;
import com.braintreepayments.api.CardResult;
import com.braintreepayments.api.DataCollector;
import com.braintreepayments.api.DataCollectorRequest;
import com.braintreepayments.api.DataCollectorResult;
import com.braintreepayments.api.GooglePayClient;
import com.braintreepayments.api.GooglePayLauncher;
import com.braintreepayments.api.GooglePayPaymentAuthRequest;
import com.braintreepayments.api.GooglePayRequest;
import com.braintreepayments.api.GooglePayResult;
import com.braintreepayments.api.PayPalAccountNonce;
import com.braintreepayments.api.PayPalCheckoutRequest;
import com.braintreepayments.api.PayPalClient;
import com.braintreepayments.api.PayPalLauncher;
import com.braintreepayments.api.PayPalPaymentAuthRequest;
import com.braintreepayments.api.PayPalPaymentAuthResult;
import com.braintreepayments.api.PayPalPendingRequest;
import com.braintreepayments.api.PayPalResult;
import com.braintreepayments.api.PayPalVaultRequest;
import com.google.android.gms.wallet.WalletConstants;

import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Promise;

import kotlin.Unit;

public class RNBraintreeDropInModule extends ReactContextBaseJavaModule {

  private static GooglePayClient googlePayClient = null;
  private static Promise pendingGooglePayPromise = null;
  private static String pendingGooglePayDeviceData = null;

  private static PayPalClient payPalClient = null;
  private static PayPalLauncher payPalLauncher = null;
  private static PayPalPendingRequest.Started pendingPayPalPendingRequest = null;
  private static Promise pendingPayPalPromise = null;
  private static String pendingPayPalDeviceData = null;

  private final BaseActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
    @Override
    public void onNewIntent(Intent intent) {
      if (payPalLauncher == null || pendingPayPalPendingRequest == null || pendingPayPalPromise == null) return;

      PayPalPaymentAuthResult authResult = payPalLauncher.handleReturnToApp(pendingPayPalPendingRequest, intent);
      if (authResult instanceof PayPalPaymentAuthResult.NoResult) return; // Chrome Custom Tab minimised

      pendingPayPalPendingRequest = null;
      Promise p = pendingPayPalPromise;
      pendingPayPalPromise = null;

      payPalClient.tokenize(authResult, result -> {
        if (result instanceof PayPalResult.Success) {
          PayPalAccountNonce nonce = ((PayPalResult.Success) result).getNonce();
          WritableMap jsResult = Arguments.createMap();
          jsResult.putString("nonce", nonce.getString());
          jsResult.putString("type", "PayPal");
          String email = nonce.getEmail();
          jsResult.putString("description", email != null ? email : "PayPal");
          jsResult.putBoolean("isDefault", nonce.isDefault());
          jsResult.putString("deviceData", pendingPayPalDeviceData != null ? pendingPayPalDeviceData : "");
          pendingPayPalDeviceData = null;
          p.resolve(jsResult);
        } else if (result instanceof PayPalResult.Failure) {
          p.reject("PAYPAL_ERROR", ((PayPalResult.Failure) result).getError().getMessage());
        } else {
          p.reject("USER_CANCELLATION", "The user cancelled");
        }
      });
    }
  };

  public RNBraintreeDropInModule(ReactApplicationContext reactContext) {
    super(reactContext);
    reactContext.addActivityEventListener(mActivityEventListener);
  }

  @ReactMethod
  public void showGooglePay(final ReadableMap options, final Promise promise) {
    if (!options.hasKey("clientToken")) {
      promise.reject("NO_CLIENT_TOKEN", "You must provide a client token");
      return;
    }
    if (!options.hasKey("orderTotal") || !options.hasKey("currencyCode")) {
      promise.reject("MISSING_OPTIONS", "You must provide orderTotal and currencyCode for Google Pay");
      return;
    }

    ComponentActivity currentActivity = (ComponentActivity) getCurrentActivity();
    if (currentActivity == null) {
      promise.reject("NO_ACTIVITY", "There is no current activity");
      return;
    }

    String token = options.getString("clientToken");
    googlePayClient = new GooglePayClient(currentActivity, token);

    DataCollector dataCollector = new DataCollector(currentActivity, token);
    dataCollector.collectDeviceData(currentActivity, new DataCollectorRequest(true), dcResult -> {
      if (dcResult instanceof DataCollectorResult.Success) {
        pendingGooglePayDeviceData = ((DataCollectorResult.Success) dcResult).getDeviceData();
      }
    });

    GooglePayRequest googlePayRequest = new GooglePayRequest();
    googlePayRequest.setCurrencyCode(options.getString("currencyCode"));
    googlePayRequest.setTotalPrice(options.getString("orderTotal"));
    googlePayRequest.setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL);
    googlePayRequest.setBillingAddressRequired(true);
    if (options.hasKey("googlePayMerchantId")) {
      googlePayRequest.setGoogleMerchantId(options.getString("googlePayMerchantId"));
    }

    pendingGooglePayPromise = promise;

    GooglePayLauncher googlePayLauncher = new GooglePayLauncher(currentActivity, gpResult -> {
      Promise p = pendingGooglePayPromise;
      pendingGooglePayPromise = null;
      if (p == null) return Unit.INSTANCE;

      if (gpResult instanceof GooglePayResult.Success) {
        WritableMap jsResult = Arguments.createMap();
        jsResult.putString("nonce", ((GooglePayResult.Success) gpResult).getNonce().getString());
        jsResult.putString("type", "Google Pay");
        jsResult.putString("description", "Google Pay");
        jsResult.putBoolean("isDefault", ((GooglePayResult.Success) gpResult).getNonce().isDefault());
        jsResult.putString("deviceData", pendingGooglePayDeviceData != null ? pendingGooglePayDeviceData : "");
        pendingGooglePayDeviceData = null;
        p.resolve(jsResult);
      } else if (gpResult instanceof GooglePayResult.Failure) {
        p.reject("GOOGLE_PAY_ERROR", ((GooglePayResult.Failure) gpResult).getError().getMessage());
      } else {
        p.reject("USER_CANCELLATION", "The user cancelled");
      }
      return Unit.INSTANCE;
    });

    googlePayClient.createPaymentAuthRequest(googlePayRequest, paymentAuthRequest -> {
      if (paymentAuthRequest instanceof GooglePayPaymentAuthRequest.ReadyToLaunch) {
        googlePayLauncher.launch((GooglePayPaymentAuthRequest.ReadyToLaunch) paymentAuthRequest);
      } else if (paymentAuthRequest instanceof GooglePayPaymentAuthRequest.Failure) {
        Promise p = pendingGooglePayPromise;
        pendingGooglePayPromise = null;
        if (p != null) p.reject("GOOGLE_PAY_ERROR", ((GooglePayPaymentAuthRequest.Failure) paymentAuthRequest).getError().getMessage());
      }
    });
  }

  @ReactMethod
  public void showPayPal(final ReadableMap options, final Promise promise) {
    if (!options.hasKey("clientToken")) {
      promise.reject("NO_CLIENT_TOKEN", "You must provide a client token");
      return;
    }

    Activity currentActivity = getCurrentActivity();
    if (currentActivity == null) {
      promise.reject("NO_ACTIVITY", "There is no current activity");
      return;
    }

    String token = options.getString("clientToken");
    String returnUrlScheme = options.hasKey("returnUrlScheme")
        ? options.getString("returnUrlScheme")
        : currentActivity.getPackageName() + ".braintree://braintree-return";
    Uri returnUri = Uri.parse(returnUrlScheme);

    payPalClient = new PayPalClient(currentActivity, token, returnUri);
    payPalLauncher = new PayPalLauncher();

    DataCollector dataCollector = new DataCollector(currentActivity, token);
    dataCollector.collectDeviceData(currentActivity, new DataCollectorRequest(true), dcResult -> {
      if (dcResult instanceof DataCollectorResult.Success) {
        pendingPayPalDeviceData = ((DataCollectorResult.Success) dcResult).getDeviceData();
      }
    });

    PayPalRequest payPalRequest;
    if (options.hasKey("amount")) {
      PayPalCheckoutRequest checkoutRequest = new PayPalCheckoutRequest(options.getString("amount"));
      if (options.hasKey("currencyCode")) checkoutRequest.setCurrencyCode(options.getString("currencyCode"));
      payPalRequest = checkoutRequest;
    } else {
      payPalRequest = new PayPalVaultRequest();
    }

    pendingPayPalPromise = promise;

    payPalClient.createPaymentAuthRequest(currentActivity, payPalRequest, authRequest -> {
      if (authRequest instanceof PayPalPaymentAuthRequest.ReadyToLaunch) {
        PayPalPendingRequest pending = payPalLauncher.launch(
            (ComponentActivity) currentActivity,
            (PayPalPaymentAuthRequest.ReadyToLaunch) authRequest
        );
        if (pending instanceof PayPalPendingRequest.Started) {
          pendingPayPalPendingRequest = (PayPalPendingRequest.Started) pending;
        } else {
          Promise p = pendingPayPalPromise;
          pendingPayPalPromise = null;
          if (p != null) p.reject("PAYPAL_LAUNCH_ERROR", "Failed to launch PayPal");
        }
      } else if (authRequest instanceof PayPalPaymentAuthRequest.Failure) {
        Promise p = pendingPayPalPromise;
        pendingPayPalPromise = null;
        if (p != null) p.reject("PAYPAL_ERROR", ((PayPalPaymentAuthRequest.Failure) authRequest).getError().getMessage());
      }
    });
  }

  @ReactMethod
  public void showCardForm(final ReadableMap options, final Promise promise) {
    if (!options.hasKey("clientToken")) {
      promise.reject("NO_CLIENT_TOKEN", "You must provide a client token");
      return;
    }

    FragmentActivity currentActivity = (FragmentActivity) getCurrentActivity();
    if (currentActivity == null) {
      promise.reject("NO_ACTIVITY", "There is no current activity");
      return;
    }

    String token = options.getString("clientToken");
    boolean darkTheme = options.hasKey("darkTheme") && options.getBoolean("darkTheme");

    currentActivity.runOnUiThread(() -> {
      RNBTCardFormFragment fragment = RNBTCardFormFragment.newInstance(token, darkTheme, promise);
      fragment.show(currentActivity.getSupportFragmentManager(), "cardForm");
    });
  }

  @ReactMethod
  public void getDeviceData(final String clientToken, final Promise promise) {
    Activity currentActivity = getCurrentActivity();
    if (currentActivity == null) {
      promise.reject("NO_ACTIVITY", "There is no current activity");
      return;
    }
    DataCollector dataCollector = new DataCollector(currentActivity, clientToken);
    dataCollector.collectDeviceData(currentActivity, new DataCollectorRequest(true), result -> {
      if (result instanceof DataCollectorResult.Success) {
        promise.resolve(((DataCollectorResult.Success) result).getDeviceData());
      } else {
        promise.reject("ERROR", "Error collecting device data");
      }
    });
  }

  @ReactMethod
  public void tokenizeCard(final String clientToken, final ReadableMap cardInfo, final Promise promise) {
    if (clientToken == null) {
      promise.reject("NO_CLIENT_TOKEN", "You must provide a client token");
      return;
    }
    if (!cardInfo.hasKey("number") || !cardInfo.hasKey("expirationMonth") ||
        !cardInfo.hasKey("expirationYear") || !cardInfo.hasKey("cvv") || !cardInfo.hasKey("postalCode")) {
      promise.reject("INVALID_CARD_INFO", "Invalid card info");
      return;
    }

    Activity currentActivity = getCurrentActivity();
    if (currentActivity == null) {
      promise.reject("NO_ACTIVITY", "There is no current activity");
      return;
    }

    CardClient cardClient = new CardClient(currentActivity, clientToken);
    Card card = new Card();
    card.setNumber(cardInfo.getString("number"));
    card.setExpirationMonth(cardInfo.getString("expirationMonth"));
    card.setExpirationYear(cardInfo.getString("expirationYear"));
    card.setCvv(cardInfo.getString("cvv"));
    card.setPostalCode(cardInfo.getString("postalCode"));

    cardClient.tokenize(card, result -> {
      if (result instanceof CardResult.Success) {
        promise.resolve(((CardResult.Success) result).getNonce().getString());
      } else if (result instanceof CardResult.Failure) {
        promise.reject("TOKENIZE_ERROR", ((CardResult.Failure) result).getError().getMessage());
      }
    });
  }

  @NonNull
  @Override
  public String getName() {
    return "RNBraintreeDropIn";
  }
}
