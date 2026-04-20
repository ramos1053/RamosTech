package com.gottago.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import android.os.Build

val GreenPrimary   = Color(0xFF2ECC71)
val GreenDark      = Color(0xFF27AE60)
val GreenContainer = Color(0xFFD5F5E3)

private val LightColors = lightColorScheme(
    primary          = GreenPrimary,
    onPrimary        = Color.White,
    primaryContainer = GreenContainer,
    secondary        = GreenDark,
    tertiary         = Color(0xFF3498DB)
)

private val DarkColors = darkColorScheme(
    primary          = GreenPrimary,
    onPrimary        = Color.Black,
    primaryContainer = Color(0xFF1A6B40),
    secondary        = GreenDark,
    tertiary         = Color(0xFF2980B9)
)

@Composable
fun GottaGoTheme(
    darkTheme: Boolean = false,
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColors
        else      -> LightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content     = content
    )
}
