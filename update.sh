#!/bin/bash
# Run inside the v2rayNG folder (the one containing V2rayNG, .github): bash update.sh
set -e
cat > V2rayNG/app/src/main/java/com/v2ray/ang/AngApplication.kt <<'KTEOF'
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
            val flag = "custom_seed_done_v2"
            if (MmkvManager.decodeSettingsBool(flag, false)) return
            // Let Xray resolve the outbound domain itself (don't pin the first resolved IP)
            MmkvManager.encodeSettings(AppConfig.PREF_OUTBOUND_DOMAIN_RESOLVE_METHOD, "1")
            MmkvManager.encodeSettings(AppConfig.PREF_LOGLEVEL, "debug")
            MmkvManager.encodeSettings(AppConfig.PREF_MUX_ENABLED, false)
            MmkvManager.encodeSettings(AppConfig.PREF_FAKE_DNS_ENABLED, false)
            MmkvManager.encodeSettings(AppConfig.PREF_PREFER_IPV6, false)

            val uuid = "9560e4fd-653b-4f36-bba8-1f1582c7c723"
            val worker = "old-leaf-638e.mohammadbaghir22.workers.dev"
            val tail = "&sni=fin.mediayar.com&insecure=0&allowInsecure=0&type=ws&host=fin.mediayar.com&path=%2Fr"
            val chrome = "&fp=chrome&alpn=http%2F1.1"
            val alpnOnly = "&alpn=http%2F1.1"
            val ip1 = "104.21.95.223"
            val ip2 = "172.67.171.125"

            fun link(addr: String, extra: String, name: String) =
                "vless://$uuid@$addr:443?encryption=none&security=tls$extra$tail#$name"

            val links = listOf(
                link(worker, "", "T01-domain-plain"),
                link(worker, chrome, "T02-domain-chrome-h1"),
                link(worker, alpnOnly, "T03-domain-h1"),
                link(ip1, "", "T04-ip1-plain"),
                link(ip1, chrome, "T05-ip1-chrome-h1"),
                link(ip1, alpnOnly, "T06-ip1-h1"),
                link(ip2, "", "T07-ip2-plain"),
                link(ip2, chrome, "T08-ip2-chrome-h1"),
                link(ip2, alpnOnly, "T09-ip2-h1")
            )
            for (l in links) {
                val result = AngConfigManager.importBatchConfig(l, "", false)
                com.v2ray.ang.util.LogUtil.i(AppConfig.TAG, "Seeded profile: $result")
            }
            MmkvManager.encodeSettings(flag, true)
        } catch (e: Exception) {
            com.v2ray.ang.util.LogUtil.e(AppConfig.TAG, "Seeding default profiles failed", e)
        }
    }
}
KTEOF
git add -A
git commit -m "multi-profile test build" || true
git push -u origin main
echo "DONE - now check the Actions tab on GitHub"
