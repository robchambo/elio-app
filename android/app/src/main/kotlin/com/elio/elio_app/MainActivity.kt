package com.elio.elio_app

import android.media.AudioManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {

    private val CHANNEL = "com.elio/audio"
    private var savedNotificationVolume: Int = -1
    private var savedSystemVolume: Int = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "muteBeep" -> {
                        // 19 May 2026 — DO NOT mute STREAM_MUSIC. flutter_tts
                        // plays its speech output on STREAM_MUSIC by default,
                        // so zeroing this stream silently broke all TTS the
                        // moment the user enabled voice control in Cook Mode.
                        // Rob's 19may-c diagnosis: "after tapping the mic,
                        // TTS plays silently in the background." Mute only
                        // the notification + system streams where Android's
                        // STT recogniser actually emits its ready-to-listen
                        // beep — STREAM_MUSIC is over-broad and was never
                        // the right target.
                        savedNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
                        savedSystemVolume = audioManager.getStreamVolume(AudioManager.STREAM_SYSTEM)
                        audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
                        audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
                        result.success(true)
                    }
                    "restoreBeep" -> {
                        if (savedNotificationVolume >= 0) {
                            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)
                            savedNotificationVolume = -1
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
