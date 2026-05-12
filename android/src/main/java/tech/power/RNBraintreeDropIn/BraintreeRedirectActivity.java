package tech.power.RNBraintreeDropIn;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import com.braintreepayments.api.DropInActivity;

public class BraintreeRedirectActivity extends Activity {
    private static final String EXTRA_CHECKOUT_REQUEST = "com.braintreepayments.api.EXTRA_CHECKOUT_REQUEST";
    private static final String EXTRA_CHECKOUT_REQUEST_BUNDLE = "com.braintreepayments.api.EXTRA_CHECKOUT_REQUEST_BUNDLE";
    private static final String EXTRA_AUTHORIZATION = "com.braintreepayments.api.EXTRA_AUTHORIZATION";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Uri redirectUri = getIntent().getData();
        if (redirectUri != null
                && RNBraintreeDropInModule.dropInActive
                && RNBraintreeDropInModule.lastDropInRequest != null
                && RNBraintreeDropInModule.clientToken != null) {
            Bundle dropInRequestBundle = new Bundle();
            dropInRequestBundle.putParcelable(EXTRA_CHECKOUT_REQUEST, RNBraintreeDropInModule.lastDropInRequest);
            Intent dropInIntent = new Intent(this, DropInActivity.class);
            dropInIntent.putExtra(EXTRA_CHECKOUT_REQUEST_BUNDLE, dropInRequestBundle);
            dropInIntent.putExtra(EXTRA_AUTHORIZATION, RNBraintreeDropInModule.clientToken);
            dropInIntent.setData(redirectUri);
            startActivity(dropInIntent);
        }
        finish();
    }
}
