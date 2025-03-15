package com.quash.testapp

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.quash.bugs.sdkhelper.Quash
import com.quash.testapp.ui.theme.MyApplicationTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException

class MainActivity : ComponentActivity() {
    private val TAG = "QuashTest"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyApplicationTheme {
                val context = LocalContext.current
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Button(
                            onClick = {
                                try {
                                    // Trigger the shake detection manually to open the bug reporter
                                    Log.d(TAG, "Manually triggering shake detection")
                                    // Call onShakeDetected from Quash
                                    Quash.getInstance().onShakeDetected()
                                    Toast.makeText(context, "Triggered shake detection", Toast.LENGTH_SHORT).show()
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error opening Quash reporter", e)
                                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                                }
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Trigger Bug Reporter")
                        }
                        
                        Button(
                            onClick = {
                                try {
                                    // Use Firebase Crashlytics which is integrated with Quash
                                    Log.d(TAG, "Logging exception to Firebase Crashlytics")
                                    val testException = RuntimeException("Test non-fatal crash for Quash")
                                    com.google.firebase.crashlytics.FirebaseCrashlytics.getInstance().recordException(testException)
                                    Toast.makeText(context, "Exception logged via Firebase Crashlytics", Toast.LENGTH_SHORT).show()
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error in test crash logging", e)
                                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                                }
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Test Crash Logging")
                        }
                        
                        Button(
                            onClick = {
                                testNetworkRequest(context)
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Test Network Interception")
                        }
                        
                        Button(
                            onClick = {
                                try {
                                    Log.d(TAG, "Saving network logs")
                                    // Call saveFilePathForNetwork directly
                                    Quash.getInstance().saveFilePathForNetwork()
                                    Toast.makeText(context, "Network logs saved", Toast.LENGTH_SHORT).show()
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error saving network logs", e)
                                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                                }
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Save Network Logs")
                        }
                        
                        Button(
                            onClick = {
                                try {
                                    Log.d(TAG, "Clearing network logs")
                                    // Call clearNetworkLogs directly
                                    Quash.getInstance().clearNetworkLogs()
                                    Toast.makeText(context, "Network logs cleared", Toast.LENGTH_SHORT).show()
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error clearing network logs", e)
                                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                                }
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Clear Network Logs")
                        }
                        
                        Button(
                            onClick = {
                                checkQuashInitialization(context)
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Check Quash Status")
                        }
                        
                        Button(
                            onClick = {
                                // This will actually crash the app
                                Toast.makeText(context, "App will crash in 2 seconds...", Toast.LENGTH_SHORT).show()
                                
                                // Delay to allow toast to show before crash
                                CoroutineScope(Dispatchers.Main).launch {
                                    kotlinx.coroutines.delay(2000)
                                    throw RuntimeException("Intentional crash to test Quash crash reporting")
                                }
                            },
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Text("Force Real Crash")
                        }
                        
                        BakingScreen()
                    }
                }
            }
        }
    }
    
    private fun testNetworkRequest(context: android.content.Context) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Use NetworkManager's client which has Quash interceptor
                val client = NetworkManager.client
                val request = Request.Builder()
                    .url("https://jsonplaceholder.typicode.com/todos/1")
                    .get()
                    .build()
                
                Log.d(TAG, "Sending test request...")
                client.newCall(request).execute().use { response ->
                    val responseBody = response.body?.string() ?: "Empty response"
                    Log.d(TAG, "Response: $responseBody")
                    
                    CoroutineScope(Dispatchers.Main).launch {
                        Toast.makeText(
                            context,
                            "Request sent! Check logs for details",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network request failed", e)
                CoroutineScope(Dispatchers.Main).launch {
                    Toast.makeText(
                        context,
                        "Network request failed: ${e.message}",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
    }

    private fun checkQuashInitialization(context: android.content.Context) {
        try {
            val quashInstance = Quash.getInstance()
            val isInitialized = quashInstance != null
            
            Log.d(TAG, "Quash instance exists: $isInitialized")
            Log.d(TAG, "Quash class: ${quashInstance?.javaClass?.name}")
            
            // Check if network interceptor is available
            val networkInterceptor = Quash.getInstance().getNetworkInterceptor()
            val hasNetworkInterceptor = networkInterceptor != null
            Log.d(TAG, "Has network interceptor: $hasNetworkInterceptor")
            
            Toast.makeText(
                context,
                "Quash initialized: $isInitialized, Network: $hasNetworkInterceptor",
                Toast.LENGTH_LONG
            ).show()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Quash status", e)
            Toast.makeText(
                context,
                "Error checking Quash: ${e.message}",
                Toast.LENGTH_LONG
            ).show()
        }
    }
} 