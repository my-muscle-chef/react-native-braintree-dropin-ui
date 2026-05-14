package tech.power.RNBraintreeDropIn;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

public class BraintreeRedirectActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Uri redirectUri = getIntent().getData();
        if (redirectUri != null) {
            // Forward the deep-link intent to the main activity so React Native's
            // onNewIntent fires and PayPalLauncher.handleReturnToApp can process it.
            Intent mainIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
            if (mainIntent != null) {
                mainIntent.setAction(Intent.ACTION_VIEW);
                mainIntent.setData(redirectUri);
                mainIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(mainIntent);
            }
        }
        finish();
    }
}
