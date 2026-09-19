package com.music.spotui.shared.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.ComposeUIViewController

object MeloBridgeUiController {
    fun bottomNavigation(
        selectedRoute: String,
        onTabSelected: (String) -> Unit,
    ) = ComposeUIViewController {
        MeloBridgeTheme {
            Box(Modifier.fillMaxSize().background(MeloBridgeColors.Background)) {
                MeloBottomNavigation(
                    selectedTab = MeloRootTab.fromRoute(selectedRoute),
                    onTabSelected = { onTabSelected(it.route) },
                )
            }
        }
    }
}
