package com.checkshipping.check_shipping

import android.content.Context
import android.provider.Settings
import java.io.ByteArrayOutputStream

/// Reads the user-selected Samsung FlipFont so Flutter text can match the
/// system font. Extracted from MainActivity so any engine can serve it.
object SamsungFlipFontReader {
    private val FLIP_FONT_PACKAGES = listOf(
        "com.monotype.android.font.samsungone",
        "com.monotype.android.font.samsungsans",
        "com.monotype.android.font.applemint",
        "com.monotype.android.font.cooljazz",
        "com.monotype.android.font.chococooky",
        "com.monotype.android.font.tinkerbell",
        "com.monotype.android.font.sdmisaeng",
        "com.monotype.android.font.foundation",
        "com.monotype.android.font.roboto",
    )

    fun read(context: Context): ByteArray? {
        val fontStyleIndex = readFontStyleIndex(context)
        if (fontStyleIndex <= 0) {
            return null
        }
        val selected = when (fontStyleIndex) {
            1 -> "com.monotype.android.font.samsungone"
            2 -> "com.monotype.android.font.samsungsans"
            3 -> "com.monotype.android.font.applemint"
            4 -> "com.monotype.android.font.cooljazz"
            5 -> "com.monotype.android.font.chococooky"
            6 -> "com.monotype.android.font.tinkerbell"
            7 -> "com.monotype.android.font.sdmisaeng"
            else -> null
        }
        val candidates = (listOfNotNull(selected) + FLIP_FONT_PACKAGES).distinct()
        for (packageName in candidates) {
            val bytes = readFirstFontAsset(context, packageName)
            if (bytes != null) return bytes
        }
        return null
    }

    private fun readFontStyleIndex(context: Context): Int {
        val global = Settings.Global.getInt(
            context.contentResolver,
            "font_style_index",
            0,
        )
        if (global > 0) return global
        return Settings.System.getInt(
            context.contentResolver,
            "font_style_index",
            0,
        )
    }

    private fun readFirstFontAsset(context: Context, packageName: String): ByteArray? {
        val packageContext = try {
            context.createPackageContext(packageName, 0)
        } catch (_: Exception) {
            return null
        }
        val assets = packageContext.assets
        val fontFiles = try {
            assets.list("fonts")?.filter {
                it.endsWith(".ttf", ignoreCase = true) || it.endsWith(".otf", ignoreCase = true)
            }
        } catch (_: Exception) {
            null
        }.orEmpty()
        for (fontFile in fontFiles) {
            try {
                assets.open("fonts/$fontFile").use { input ->
                    val output = ByteArrayOutputStream()
                    input.copyTo(output)
                    return output.toByteArray()
                }
            } catch (_: Exception) {
                continue
            }
        }
        return null
    }
}
