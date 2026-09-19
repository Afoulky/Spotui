package com.music.spotui.shared.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text

enum class MeloRootTab(val route: String, val label: String) {
    Home("home", "Home"),
    Search("search", "Search"),
    Library("library", "Library");

    companion object {
        fun fromRoute(route: String): MeloRootTab = entries.firstOrNull { it.route == route } ?: Home
    }
}

@Composable
fun MeloBottomNavigation(
    selectedTab: MeloRootTab,
    onTabSelected: (MeloRootTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(64.dp)
            .padding(horizontal = 24.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        MeloRootTab.entries.forEach { tab ->
            val selected = tab == selectedTab
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        role = Role.Tab,
                    ) { onTabSelected(tab) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                NavigationIcon(tab, selected)
                Text(
                    text = tab.label,
                    color = if (selected) Color.White else MeloBridgeColors.SecondaryText,
                    fontSize = 11.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun NavigationIcon(tab: MeloRootTab, selected: Boolean) {
    val color = if (selected) Color.White else MeloBridgeColors.SecondaryText
    Canvas(Modifier.height(24.dp).fillMaxWidth(0.28f)) {
        val stroke = Stroke(width = 2.2.dp.toPx(), cap = StrokeCap.Round)
        when (tab) {
            MeloRootTab.Home -> {
                val roof = Path().apply {
                    moveTo(size.width * 0.15f, size.height * 0.48f)
                    lineTo(size.width * 0.5f, size.height * 0.17f)
                    lineTo(size.width * 0.85f, size.height * 0.48f)
                }
                drawPath(roof, color, style = stroke)
                drawRect(
                    color = color,
                    topLeft = Offset(size.width * 0.25f, size.height * 0.45f),
                    size = Size(size.width * 0.5f, size.height * 0.4f),
                    style = stroke,
                )
            }
            MeloRootTab.Search -> {
                drawCircle(color, radius = size.minDimension * 0.28f, center = Offset(size.width * 0.43f, size.height * 0.42f), style = stroke)
                drawLine(color, Offset(size.width * 0.63f, size.height * 0.63f), Offset(size.width * 0.82f, size.height * 0.82f), stroke.width, StrokeCap.Round)
            }
            MeloRootTab.Library -> {
                drawLine(color, Offset(size.width * 0.22f, size.height * 0.2f), Offset(size.width * 0.22f, size.height * 0.82f), stroke.width, StrokeCap.Round)
                drawLine(color, Offset(size.width * 0.42f, size.height * 0.2f), Offset(size.width * 0.42f, size.height * 0.82f), stroke.width, StrokeCap.Round)
                drawLine(color, Offset(size.width * 0.63f, size.height * 0.25f), Offset(size.width * 0.78f, size.height * 0.78f), stroke.width, StrokeCap.Round)
            }
        }
    }
}
