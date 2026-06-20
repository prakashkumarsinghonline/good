package com.example.myapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.sin

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                FunnyScreen()
            }
        }
    }
}

@Composable
fun FunnyScreen() {
    val infiniteTransition = rememberInfiniteTransition(label = "funny")

    // Spinning emoji animation
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "spin"
    )

    // Bouncing scale animation
    val bounceScale by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "bounce"
    )

    // Pulsing alpha for the subtitle
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(700),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    // Wobble animation for the big emoji
    val wobble by infiniteTransition.animateFloat(
        initialValue = -15f,
        targetValue = 15f,
        animationSpec = infiniteRepeatable(
            animation = tween(300),
            repeatMode = RepeatMode.Reverse
        ),
        label = "wobble"
    )

    // Fun color cycling
    val colorTransition = rememberInfiniteTransition(label = "color")
    val hue by colorTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "hue"
    )

    val funColor = remember(hue) {
        Color.hsl(hue, 0.8f, 0.6f)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1A1A2E)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Top row of bouncing emojis
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(bottom = 16.dp)
        ) {
            BouncingEmoji("😂", bounceScale)
            BouncingEmoji("🤣", bounceScale)
            BouncingEmoji("🤡", bounceScale)
            BouncingEmoji("😂", bounceScale)
            BouncingEmoji("🤣", bounceScale)
        }

        // Big spinning emoji
        Text(
            text = "🤪",
            fontSize = 80.sp,
            modifier = Modifier
                .scale(bounceScale)
                .rotate(rotation)
                .padding(8.dp)
        )

        // Main title with fun wobble
        Text(
            text = "Hello World! 🎉",
            fontSize = 36.sp,
            fontWeight = FontWeight.ExtraBold,
            color = funColor,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(16.dp)
                .scale(bounceScale)
        )

        // Funny subtitle
        Text(
            text = "Praksh Baby 👶",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFFFFD700),
            textAlign = TextAlign.Center,
            modifier = Modifier
                .alpha(pulseAlpha)
                .padding(8.dp)
        )

        // Funny rotating emojis row
        Row(
            horizontalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier.padding(top = 24.dp)
        ) {
            RotatingEmoji("🍌", wobble)
            RotatingEmoji("🫠", -wobble)
            RotatingEmoji("🐔", wobble)
            RotatingEmoji("💩", -wobble)
        }

        // Silly tagline
        Text(
            text = "📱 This app costs 1 million dollars 💸",
            fontSize = 14.sp,
            color = Color(0xFFAAAAAA),
            modifier = Modifier
                .padding(top = 24.dp)
                .alpha(pulseAlpha)
        )

        // Bottom bouncing emojis
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(top = 16.dp)
        ) {
            BouncingEmoji("🌮", bounceScale)
            BouncingEmoji("🍕", bounceScale)
            BouncingEmoji("🍩", bounceScale)
            BouncingEmoji("🌮", bounceScale)
            BouncingEmoji("🍕", bounceScale)
        }
    }
}

@Composable
fun BouncingEmoji(emoji: String, scale: Float) {
    Text(
        text = emoji,
        fontSize = 36.sp,
        modifier = Modifier.scale(scale)
    )
}

@Composable
fun RotatingEmoji(emoji: String, rotation: Float) {
    Text(
        text = emoji,
        fontSize = 40.sp,
        modifier = Modifier.rotate(rotation)
    )
}
