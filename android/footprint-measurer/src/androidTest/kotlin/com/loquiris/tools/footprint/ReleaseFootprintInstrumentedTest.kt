package com.loquiris.tools.footprint

import android.app.Instrumentation
import android.app.usage.StorageStatsManager
import android.content.Context
import android.os.BaseBundle
import android.os.Build
import android.os.Bundle
import android.os.UserHandle
import android.os.storage.StorageManager
import android.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.time.Instant
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ReleaseFootprintInstrumentedTest {
    @Test
    fun emitsPackageSpecificStorageStats() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        val targetPackage = arguments.requiredString("targetPackage")
        val buildId = arguments.requiredString("buildId")
        val installedApkSha256 = arguments.requiredSha256("installedApkSha256")
        val deviceSerial = arguments.requiredString("deviceSerial")
        val cleanInstall = arguments.requiredString("cleanInstall") == "true"
        assertTrue("host must verify a clean install", cleanInstall)

        val context = instrumentation.targetContext
        val packageInfo = context.packageManager.getPackageInfo(targetPackage, 0)
        val applicationInfo = requireNotNull(packageInfo.applicationInfo)
        val storageStatsManager = context.getSystemService(StorageStatsManager::class.java)
        val user = UserHandle.getUserHandleForUid(applicationInfo.uid)
        val stats =
            storageStatsManager.queryStatsForPackage(
                StorageManager.UUID_DEFAULT,
                targetPackage,
                user,
            )

        val payload =
            JSONObject()
                .put("schemaVersion", 1)
                .put("buildId", buildId)
                .put("packageName", targetPackage)
                .put("versionCode", packageInfo.longVersionCode)
                .put("deviceSerial", deviceSerial)
                .put("deviceModel", Build.MODEL)
                .put("buildFingerprint", Build.FINGERPRINT)
                .put("observedAtUtc", Instant.now().toString())
                .put("cleanInstall", true)
                .put("installedApkSha256", installedApkSha256)
                .put("appBytes", stats.appBytes)
                .put("dataBytes", stats.dataBytes)
                .put("cacheBytes", stats.cacheBytes)
                .toString()
        val encoded =
            Base64.encodeToString(
                payload.toByteArray(Charsets.UTF_8),
                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
            )
        instrumentation.sendStatus(
            0,
            Bundle().apply { putString("loquirisFootprint", encoded) },
        )
    }
}

private fun BaseBundle.requiredString(key: String): String =
    requireNotNull(getString(key)).also { require(it.isNotEmpty()) }

private fun BaseBundle.requiredSha256(key: String): String =
    requiredString(key).also { require(it.matches(Regex("[0-9a-f]{64}"))) }
