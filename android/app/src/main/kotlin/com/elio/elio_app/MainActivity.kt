package com.elio.elio_app

import android.media.AudioManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {

    private val CHANNEL = "com.elio/audio"
    private var savedNotificationVolume: Int = -1
    private var savedMusicVolume: Int = -1
    private var savedSystemVolume: Int = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "muteBeep" -> {
                        // Save and mute all streams that might carry the recogniser beep
                        savedNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
                        savedMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        savedSystemVolume = audioManager.getStreamVolume(AudioManager.STREAM_SYSTEM)
                        audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
                        audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
                        result.success(true)
                    }
                    "restoreBeep" -> {
                        if (savedNotificationVolume >= 0) {
                            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)
                            savedNotificationVolume = -1
                        }
                        if (savedMusicVolume >= 0) {
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, savedMusicVolume, 0)
                            savedMusicVolume = -1
                        }
                        if (savedSystemVolume >= 0) {
                            audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, savedSystemVolume, 0)
                            savedSystemVolume = -1
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
