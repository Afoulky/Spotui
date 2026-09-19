package com.music.spotui.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.music.spotui.ui.components.MiniPlayer
import com.music.spotui.shared.ui.MeloBottomNavigation
import com.music.spotui.shared.ui.MeloRootTab

@Composable
fun MainBottomNavigation(navController: NavHostController, bottomBarState: MutableState<Boolean>, bottomBarPlayerState : MutableState<Boolean>, onSearchReselected: () -> Unit = {}) {

    AnimatedVisibility(
        visible = bottomBarState.value,
        enter = slideInVertically(initialOffsetY = { it }),
        exit = slideOutVertically(targetOffsetY = { it }),
        content = {
            Box(
                contentAlignment = Alignment.BottomCenter,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black,
                                Color.Black
                            ),
                            startY = 0f
                        )
                    )
            ) {

                Column(
                    modifier = Modifier.navigationBarsPadding()
                ) {

                    AnimatedVisibility(
                        visible = bottomBarPlayerState.value,
                        enter = slideInVertically(initialOffsetY = { it }),
                        exit = slideOutVertically(targetOffsetY = { it }),
                        content = {
                            MiniPlayer(navController)
                        }
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    val navStack by navController.currentBackStackEntryAsState()
                    val currentRoute = navStack?.destination?.route
                    val rootRoutes = listOf(Routes.Home.route, Routes.Search.route, Routes.Library.route)
                    var currentTab by rememberSaveable { mutableStateOf(Routes.Home.route) }
                    if (currentRoute in rootRoutes) {
                        currentTab = currentRoute!!
                    }

                    MeloBottomNavigation(
                        modifier = Modifier
                            .padding(30.dp, 0.dp)
                            .fillMaxWidth(),
                        selectedTab = MeloRootTab.fromRoute(currentTab),
                        onTabSelected = { item ->
                            if (currentTab != item.route) {
                                navController.navigate(item.route) {
                                    navController.graph.startDestinationRoute?.let { startRoute ->
                                        popUpTo(startRoute) { saveState = true }
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            } else if (currentRoute != item.route) {
                                navController.popBackStack(item.route, inclusive = false)
                            } else if (item == MeloRootTab.Search) {
                                onSearchReselected()
                            }
                        }
                    )



                }



            }
        }
    )
}
