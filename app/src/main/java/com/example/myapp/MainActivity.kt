package com.example.myapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Composable
fun EmojiRace() {
    val scope = rememberCoroutineScope()
    val startOffset = remember { mutableStateOf(0f) }
    val isRaceActive = remember { mutableStateOf(false) }

    val emojiStyles = listOf(
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
        "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
        "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔"
    )

    LaunchedEffect(Unit) {
        // Start race after 1 second
        delay(1000)
        isRaceActive.value = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                MaterialTheme.colorScheme.primary
            )
    ) {
        // Start line
        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "🏁 START LINE 🏁",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(bottom = 20.dp)
            )
            Text(
                text = "GO!",
                fontSize = 48.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White,
                modifier = Modifier.animateEnterExit(
                    animationSpec = fadeIn(tween(300)) + scaleIn(tween(300))
                )
            )
        }

        // Racing emojis
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            val emojis = remember { emojiStyles.shuffled() }
            emojis.forEach { emoji ->
                RacingEmoji(
                    emoji = emoji,
                    startOffset = startOffset,
                    isRaceActive = isRaceActive.value,
                    onFinished = {
                        // Handle emoji finished (could add sound effect here)
                    }
                )
            }
        }

        // Finish line
        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "🏆 FINISH LINE 🏆",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                alpha = 0f
            )
        }

        // Instructions
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Watch the emoji race!",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.white.copy(alpha = 0.8f)
            )
        }
    }
}

@Composable
fun RacingEmoji(
    emoji: String,
    startOffset: MutableState<Float>,
    isRaceActive: Boolean,
    onFinished: () -> Unit
) {
    val progress = animateFloatAsState(
        targetValue = if (isRaceActive) 1f else 0f,
        animationSpec = tween(
            durationMillis = 3000 + (startOffset.value * 1000).toInt(),
            easing = FastOutSlowInEasing
        )
    )

    val scale by animateFloatAsState(
        targetValue = if (isRaceActive) 1.2f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy)
    )

    val rotation by animateFloatAsState(
        targetValue = if (isRaceActive) 360f else 0f,
        animationSpec = tween(durationMillis = 3000 + (startOffset.value * 1000).toInt())
    )

    val alpha by animateFloatAsState(
        targetValue = if (isRaceActive) 1f else 0.3f,
        animationSpec = tween(durationMillis = 1000)
    )

    LaunchedEffect(isRaceActive) {
        if (isRaceActive && progress.value == 1f) {
            onFinished()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .offset(x = startOffset.value.dp)
            .graphicsLayer {
                rotationZ = rotation
                alpha = alpha
            }
    ) {
        Text(
            text = emoji,
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                EmojiRace()
            }
        }
    }
}
