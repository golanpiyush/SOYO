package com.example.soyo

import android.media.AudioManager
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.soyo.audio/boost"
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var audioSessionId: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initAudioBoost" -> {
                    try {
                        // Get audio session ID (0 is global)
                        audioSessionId = 0
                        loudnessEnhancer = LoudnessEnhancer(audioSessionId)
                        loudnessEnhancer?.enabled = true
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }
                "setAudioBoost" -> {
                    try {
                        val multiplier = call.argument<Double>("multiplier") ?: 1.0
                        // LoudnessEnhancer accepts gain in millibels (mB)
                        // 1000 mB = 1 dB
                        // For 2x volume: ~6 dB = 6000 mB
                        // For 3x volume: ~9.5 dB = 9500 mB
                        // For 4x volume: ~12 dB = 12000 mB
                        val gainMb = when {
                            multiplier <= 1.0 -> 0
                            multiplier >= 4.0 -> 12000
                            multiplier >= 3.0 -> 9500
                            multiplier >= 2.0 -> 6000
                            else -> ((multiplier - 1.0) * 6000).toInt()
                        }
                        
                        loudnessEnhancer?.setTargetGain(gainMb)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BOOST_ERROR", e.message, null)
                    }
                }
                "releaseAudioBoost" -> {
                    try {
                        loudnessEnhancer?.release()
                        loudnessEnhancer = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RELEASE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}