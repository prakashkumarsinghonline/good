package com.example.ahamaiapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlin.math.abs
import kotlin.random.Random

private const val BoardSize = 18

private data class Cell(val x: Int, val y: Int)

private enum class Direction {
    Up, Down, Left, Right
}

private class GameModel {
    val snake = mutableStateListOf<Cell>()
    var direction by mutableStateOf(Direction.Right)
    var nextDirection by mutableStateOf(Direction.Right)
    var snack by mutableStateOf(Cell(11, 9))
    var score by mutableIntStateOf(0)
    var best by mutableIntStateOf(0)
    var burps by mutableIntStateOf(0)
    var isRunning by mutableStateOf(false)
    var isGameOver by mutableStateOf(false)
    var headline by mutableStateOf("Tap START. The noodle is hungry.")
    var snackEmoji by mutableStateOf("🍕")
    var partyModeTicks by mutableIntStateOf(0)

    init {
        reset()
    }

    fun reset() {
        snake.clear()
        snake.addAll(listOf(Cell(7, 9), Cell(6, 9), Cell(5, 9), Cell(4, 9)))
        direction = Direction.Right
        nextDirection = Direction.Right
        score = 0
        burps = 0
        partyModeTicks = 0
        isRunning = false
        isGameOver = false
        headline = funnyStartLines.random()
        snackEmoji = snackEmojis.random()
        snack = randomEmptyCell()
    }

    fun start() {
        if (isGameOver) reset()
        isRunning = true
        headline = "Sssssnack attack! Swipe to steer."
    }

    fun pause() {
        isRunning = false
        headline = "Paused. The snake is filing taxes."
    }

    fun turn(newDirection: Direction) {
        if (!direction.isOpposite(newDirection)) {
            nextDirection = newDirection
        }
    }

    fun step() {
        if (!isRunning || isGameOver) return

        direction = nextDirection
        val head = snake.first()
        val newHead = when (direction) {
            Direction.Up -> head.copy(y = head.y - 1)
            Direction.Down -> head.copy(y = head.y + 1)
            Direction.Left -> head.copy(x = head.x - 1)
            Direction.Right -> head.copy(x = head.x + 1)
        }

        val hitsWall = newHead.x !in 0 until BoardSize || newHead.y !in 0 until BoardSize
        val hitsSelf = snake.contains(newHead)
        if (hitsWall || hitsSelf) {
            isRunning = false
            isGameOver = true
            best = maxOf(best, score)
            headline = if (hitsWall) {
                "Bonk! That wall was not a snack."
            } else {
                "Oops. Self-snacking is frowned upon."
            }
            return
        }

        snake.add(0, newHead)
        if (newHead == snack) {
            score += if (partyModeTicks > 0) 2 else 1
            burps += 1
            best = maxOf(best, score)
            partyModeTicks = if (Random.nextInt(5) == 0) 10 else partyModeTicks
            snackEmoji = snackEmojis.random()
            snack = randomEmptyCell()
            headline = funnyEatLines.random()
        } else {
            snake.removeLast()
        }

        if (partyModeTicks > 0) {
            partyModeTicks -= 1
            if (partyModeTicks == 0) headline = "Party mode ended. Very professional now."
        }
    }

    private fun randomEmptyCell(): Cell {
        val openCells = buildList {
            for (y in 0 until BoardSize) {
                for (x in 0 until BoardSize) {
                    val cell = Cell(x, y)
                    if (!snake.contains(cell)) add(cell)
                }
            }
        }
        return openCells.random()
    }
}

private fun Direction.isOpposite(other: Direction): Boolean {
    return (this == Direction.Up && other == Direction.Down) ||
        (this == Direction.Down && other == Direction.Up) ||
        (this == Direction.Left && other == Direction.Right) ||
        (this == Direction.Right && other == Direction.Left)
}

private val funnyStartLines = listOf(
    "Welcome to Snakers: legally distinct noodle chaos.",
    "Tap START. The snake has tiny business plans.",
    "No gradients. Just pure reptile drama.",
    "This snake skipped breakfast and common sense."
)

private val funnyEatLines = listOf(
    "Cronch! Absolutely no manners.",
    "The noodle grows. Society trembles.",
    "Snack secured. Burp pending.",
    "Yum! The snake now believes in itself.",
    "That snack had a family. Delicious."
)

private val snackEmojis = listOf("🍕", "🌮", "🍩", "🧀", "🥨", "🍔", "🧁", "🥑")

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SnakersApp()
        }
    }
}

@Composable
private fun SnakersApp() {
    val model = remember { GameModel() }
    val tickMs = if (model.partyModeTicks > 0) 95L else maxOf(70L, 175L - model.score * 4L)
    val wiggle = remember { Animatable(0f) }

    LaunchedEffect(model.isRunning, tickMs) {
        while (model.isRunning) {
            delay(tickMs)
            model.step()
        }
    }

    LaunchedEffect(model.score) {
        if (model.score > 0) {
            wiggle.snapTo(0f)
            wiggle.animateTo(1f, animationSpec = tween(90))
            wiggle.animateTo(0f, animationSpec = tween(90))
        }
    }

    MaterialTheme {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Ink
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(18.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Snakers",
                    color = Pickle,
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Black
                )
                Text(
                    text = "Funny snake. Solid colors. Maximum silliness.",
                    color = Cream,
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodyMedium
                )

                Spacer(Modifier.height(14.dp))

                ScoreCard(model)

                Spacer(Modifier.height(12.dp))

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(1f)
                        .border(4.dp, Pickle, RoundedCornerShape(18.dp))
                        .background(Board, RoundedCornerShape(18.dp))
                        .padding(10.dp)
                        .pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                val (dx, dy) = dragAmount
                                if (abs(dx) > abs(dy)) {
                                    model.turn(if (dx > 0) Direction.Right else Direction.Left)
                                } else {
                                    model.turn(if (dy > 0) Direction.Down else Direction.Up)
                                }
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    SnakersBoard(model, wiggle.value)
                    if (!model.isRunning) {
                        StatusOverlay(model)
                    }
                }

                Spacer(Modifier.height(12.dp))

                Text(
                    text = model.headline,
                    color = Banana,
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(14.dp))

                Controls(model)
            }
        }
    }
}

@Composable
private fun ScoreCard(model: GameModel) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Panel),
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.SpaceAround
        ) {
            ScoreText("Score", model.score.toString())
            ScoreText("Best", model.best.toString())
            ScoreText("Burps", "💨 ${model.burps}")
            ScoreText("Mode", if (model.partyModeTicks > 0) "PARTY" else "Sneaky")
        }
    }
}

@Composable
private fun ScoreText(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = Cream, style = MaterialTheme.typography.labelMedium)
        Text(value, color = Pickle, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun SnakersBoard(model: GameModel, wiggle: Float) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val cell = size.width / BoardSize
        for (index in 0..BoardSize) {
            val line = index * cell
            drawLine(Grid, Offset(line, 0f), Offset(line, size.height), strokeWidth = 1.5f)
            drawLine(Grid, Offset(0f, line), Offset(size.width, line), strokeWidth = 1.5f)
        }

        val snackCenter = Offset(
            x = model.snack.x * cell + cell / 2f,
            y = model.snack.y * cell + cell / 2f
        )
        drawCircle(
            color = Snack,
            radius = cell * (0.34f + wiggle * 0.08f),
            center = snackCenter
        )
        drawCircle(
            color = Cream,
            radius = cell * 0.15f,
            center = snackCenter
        )

        model.snake.forEachIndexed { index, part ->
            val isHead = index == 0
            val inset = if (isHead) cell * 0.08f else cell * 0.13f
            val wobble = if (model.partyModeTicks > 0 && index % 2 == 0) cell * 0.04f else 0f
            drawRoundRect(
                color = if (isHead) Pickle else SnakeBody,
                topLeft = Offset(part.x * cell + inset + wobble, part.y * cell + inset),
                size = Size(cell - inset * 2f, cell - inset * 2f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(cell * 0.22f)
            )
            if (isHead) {
                val eyeY = part.y * cell + cell * 0.33f
                drawCircle(Color.Black, cell * 0.055f, Offset(part.x * cell + cell * 0.36f, eyeY))
                drawCircle(Color.Black, cell * 0.055f, Offset(part.x * cell + cell * 0.64f, eyeY))
            }
        }

        drawRect(
            color = Pickle,
            style = Stroke(width = 5f),
            size = size
        )
    }

    Text(
        text = model.snackEmoji,
        style = MaterialTheme.typography.headlineMedium
    )
}

@Composable
private fun StatusOverlay(model: GameModel) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Overlay),
        shape = RoundedCornerShape(20.dp)
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = if (model.isGameOver) "GAME OVER" else "READY?",
                color = Banana,
                fontWeight = FontWeight.Black,
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = if (model.isGameOver) "Tap restart and avenge the noodle." else "Swipe anywhere on the board.",
                color = Cream,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun Controls(model: GameModel) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Button(
            onClick = { if (model.isRunning) model.pause() else model.start() },
            colors = ButtonDefaults.buttonColors(containerColor = Pickle, contentColor = Ink)
        ) {
            Text(if (model.isRunning) "Pause" else if (model.isGameOver) "Restart" else "Start")
        }
        Button(
            onClick = { model.reset() },
            colors = ButtonDefaults.buttonColors(containerColor = Banana, contentColor = Ink)
        ) {
            Text("Reset Chaos")
        }
    }

    Spacer(Modifier.height(12.dp))

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        DPadButton("▲") { model.turn(Direction.Up) }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            DPadButton("◀") { model.turn(Direction.Left) }
            DPadButton("▶") { model.turn(Direction.Right) }
        }
        DPadButton("▼") { model.turn(Direction.Down) }
    }
}

@Composable
private fun DPadButton(label: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = Panel, contentColor = Cream),
        shape = RoundedCornerShape(14.dp)
    ) {
        Text(label, fontWeight = FontWeight.Black)
    }
}

private val Ink = Color(0xFF101416)
private val Board = Color(0xFF18201C)
private val Panel = Color(0xFF24302A)
private val Grid = Color(0xFF314037)
private val Pickle = Color(0xFF9BDE5A)
private val SnakeBody = Color(0xFF5EB344)
private val Snack = Color(0xFFFF6B5E)
private val Banana = Color(0xFFFFD166)
private val Cream = Color(0xFFFFF1D6)
private val Overlay = Color(0xEE101416)