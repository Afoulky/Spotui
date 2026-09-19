package com.music.spotui.shared.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object MeloBridgeColors {
    val Background = Color(0xFF0B0B0F)
    val Surface = Color(0xFF2A2A2A)
    val Accent = Color(0xFF618DFF)
    val SpotifyGreen = Color(0xFF1ED760)
    val PrimaryText = Color.White
    val SecondaryText = Color(0xFFB3B3B3)
}

private val MeloBridgeColorScheme = darkColorScheme(
    primary = MeloBridgeColors.Accent,
    secondary = MeloBridgeColors.SpotifyGreen,
    background = MeloBridgeColors.Background,
    surface = MeloBridgeColors.Surface,
    onPrimary = MeloBridgeColors.PrimaryText,
    onSecondary = Color.Black,
    onBackground = MeloBridgeColors.PrimaryText,
    onSurface = MeloBridgeColors.PrimaryText,
)

@Composable
fun MeloBridgeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MeloBridgeColorScheme,
        content = content,
    )
}
