package com.music.spotui.shared.ui

import kotlin.test.Test
import kotlin.test.assertEquals

class MeloRootTabTest {
    @Test
    fun routesStayCompatibleWithBothPlatformNavigators() {
        assertEquals(MeloRootTab.Home, MeloRootTab.fromRoute("home"))
        assertEquals(MeloRootTab.Search, MeloRootTab.fromRoute("search"))
        assertEquals(MeloRootTab.Library, MeloRootTab.fromRoute("library"))
        assertEquals(MeloRootTab.Home, MeloRootTab.fromRoute("unknown"))
    }
}
