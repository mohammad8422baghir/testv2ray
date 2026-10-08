package com.v2ray.ang

import android.app.Application
import android.content.Context
import androidx.core.content.ContextCompat
import androidx.work.Configuration
import androidx.work.WorkManager
import com.v2ray.ang.AppConfig.ANG_PACKAGE
import com.v2ray.ang.handler.AppLocaleManager
import com.v2ray.ang.handler.AngConfigManager
import com.v2ray.ang.handler.MmkvManager
import com.v2ray.ang.handler.SettingsManager
import com.v2ray.ang.ui.compose.ThemeManager

class AngApplication : Application() {
    companion object {
        lateinit var application: AngApplication
    }

    /**
     * Attaches the base context to the application.
     * @param base The base context.
     */
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base?.let(ContextCompat::getContextForLanguage))
        application = this
    }

    private val workManagerConfiguration: Configuration = Configuration.Builder()
        .setDefaultProcessName("${ANG_PACKAGE}:bg")
        .build()

    /**
     * Initializes the application.
     */
    override fun onCreate() {
        super.onCreate()

        MmkvManager.initialize(this)

        AppLocaleManager.initialize(this)

        // Initialize WorkManager with the custom configuration
        WorkManager.initialize(this, workManagerConfiguration)

        // Ensure critical preference defaults are present in MMKV early
        SettingsManager.initApp(this)

        // Seed the built-in profile and diagnostic defaults once, on first launch
        seedDefaultProfile()

        // Initialize theme state from MMKV
        ThemeManager.refresh()
    }

    private fun seedDefaultProfile() {
        try {
            val flag = "custom_seed_done_v1"
            if (MmkvManager.decodeSettingsBool(flag, false)) return
            // Let Xray resolve the outbound domain itself (don't pin the first resolved IP)
            MmkvManager.encodeSettings(AppConfig.PREF_OUTBOUND_DOMAIN_RESOLVE_METHOD, "1")
            MmkvManager.encodeSettings(AppConfig.PREF_LOGLEVEL, "debug")
            MmkvManager.encodeSettings(AppConfig.PREF_MUX_ENABLED, false)
            MmkvManager.encodeSettings(AppConfig.PREF_FAKE_DNS_ENABLED, false)
            MmkvManager.encodeSettings(AppConfig.PREF_PREFER_IPV6, false)
            val link = "vless://9560e4fd-653b-4f36-bba8-1f1582c7c723@old-leaf-638e.mohammadbaghir22.workers.dev:443" +
                "?encryption=none&security=tls&sni=fin.mediayar.com&fp=chrome&alpn=http%2F1.1" +
                "&insecure=0&allowInsecure=0&type=ws&host=fin.mediayar.com&path=%2Fr#My_VPS_Direct_IP"
            val result = AngConfigManager.importBatchConfig(link, "", false)
            com.v2ray.ang.util.LogUtil.i(AppConfig.TAG, "Seeded default profile: $result")
            MmkvManager.encodeSettings(flag, true)
        } catch (e: Exception) {
            com.v2ray.ang.util.LogUtil.e(AppConfig.TAG, "Seeding default profile failed", e)
        }
    }
}
