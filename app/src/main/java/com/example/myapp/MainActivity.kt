package com.example.calculator

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    Calculator()
                }
            }
        }
    }
}

@Composable
fun Calculator() {
    var displayText by remember { mutableStateOf("0") }
    var firstNumber by remember { mutableStateOf<Double?>(null) }
    var secondNumber by remember { mutableStateOf<Double?>(null) }
    var operation by remember { mutableStateOf<String?>(null) }
    var isNewNumber by remember { mutableStateOf(true) }
    var result by remember { mutableStateOf<Double?>(null) }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Display
        Text(
            text = displayText,
            style = MaterialTheme.typography.displayMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Right,
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .background(
                    color = Color.Black,
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(16.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Calculator buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Row 1
            CalculatorButton(
                text = "C",
                onClick = {
                    displayText = "0"
                    firstNumber = null
                    secondNumber = null
                    operation = null
                    result = null
                    isNewNumber = true
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "±",
                onClick = {
                    val current = displayText.toDoubleOrNull() ?: 0.0
                    displayText = (-current).toString()
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "%",
                onClick = {
                    val current = displayText.toDoubleOrNull() ?: 0.0
                    displayText = (current / 100).toString()
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "÷",
                onClick = {
                    firstNumber = displayText.toDoubleOrNull()
                    operation = "/"
                    isNewNumber = true
                },
                modifier = Modifier.weight(1f)
            )

            // Row 2
            CalculatorButton(
                text = "7",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "7" else "7"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "8",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "8" else "8"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "9",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "9" else "9"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "×",
                onClick = {
                    firstNumber = displayText.toDoubleOrNull()
                    operation = "*"
                    isNewNumber = true
                },
                modifier = Modifier.weight(1f)
            )

            // Row 3
            CalculatorButton(
                text = "4",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "4" else "4"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "5",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "5" else "5"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "6",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "6" else "6"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "−",
                onClick = {
                    firstNumber = displayText.toDoubleOrNull()
                    operation = "-"
                    isNewNumber = true
                },
                modifier = Modifier.weight(1f)
            )

            // Row 4
            CalculatorButton(
                text = "1",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "1" else "1"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "2",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "2" else "2"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "3",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "3" else "3"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "+",
                onClick = {
                    firstNumber = displayText.toDoubleOrNull()
                    operation = "+"
                    isNewNumber = true
                },
                modifier = Modifier.weight(1f)
            )

            // Row 5
            CalculatorButton(
                text = "0",
                onClick = {
                    val newText = if (isNewNumber && displayText != "0") displayText + "0" else "0"
                    displayText = newText
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = ".",
                onClick = {
                    if (isNewNumber) {
                        displayText = "0."
                        isNewNumber = false
                    } else if (displayText.indexOf('.') == -1) {
                        displayText = displayText + "."
                    }
                },
                modifier = Modifier.weight(1f)
            )
            CalculatorButton(
                text = "=",
                onClick = {
                    calculateResult()
                },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
fun CalculatorButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(60.dp),
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Gray,
            contentColor = Color.White
        )
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(16.dp)
        )
    }
}

private fun calculateResult() {
    if (firstNumber != null && operation != null && secondNumber != null) {
        val result = when (operation) {
            "+" -> firstNumber!! + secondNumber!!
            "-" -> firstNumber!! - secondNumber!!
            "*" -> firstNumber!! * secondNumber!!
            "/" -> {
                if (secondNumber!! != 0.0) firstNumber!! / secondNumber!! else 0.0
            }
            else -> 0.0
        }
        displayText = result.toString()
        firstNumber = result
        secondNumber = null
        operation = null
        isNewNumber = true
    }
}