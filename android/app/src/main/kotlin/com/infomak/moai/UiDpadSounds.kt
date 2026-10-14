package com.infomak.moai

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent

/**
 * Clicks de UI solo para control D-pad / teclado TV.
 * Ignora gamepad y joystick.
 *
 * Usa [SoundPool] (sonidos precargados, pocos streams) para no crear un
 * MediaPlayer por tecla ni saturar el hilo UI al navegar rápido.
 * Sin audio focus, para no bajar el volumen del reproductor.
 */
class UiDpadSounds(private val context: Context) {
    @Volatile
    private var enabled = true

    private var soundPool: SoundPool? = null
    @Volatile
    private var enterSoundId = 0
    @Volatile
    private var optionSoundId = 0
    private var lastPlayUptimeMs = 0L

    fun init() {
        if (soundPool != null) return

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val pool = SoundPool.Builder()
            .setMaxStreams(MAX_STREAMS)
            .setAudioAttributes(attrs)
            .build()

        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) {
                Log.i(TAG, "SoundPool OK sampleId=$sampleId")
            } else {
                Log.e(TAG, "SoundPool load falló sampleId=$sampleId status=$status")
            }
        }

        try {
            context.assets.openFd(ENTER_ASSET).use { afd ->
                enterSoundId = pool.load(afd, 1)
            }
            context.assets.openFd(OPTION_ASSET).use { afd ->
                optionSoundId = pool.load(afd, 1)
            }
            soundPool = pool
            Log.i(TAG, "SoundPool listo enterId=$enterSoundId optionId=$optionSoundId")
        } catch (e: Exception) {
            Log.e(TAG, "No se pudieron cargar WAV de UI: ${e.message}", e)
            try {
                pool.release()
            } catch (_: Exception) {
            }
            soundPool = null
            enterSoundId = 0
            optionSoundId = 0
        }
    }

    fun setEnabled(value: Boolean) {
        enabled = value
        if (!value) {
            soundPool?.autoPause()
        }
    }

    fun release() {
        try {
            soundPool?.release()
        } catch (_: Exception) {
        }
        soundPool = null
        enterSoundId = 0
        optionSoundId = 0
    }

    fun onKey(event: KeyEvent) {
        if (!enabled) return
        if (event.action != KeyEvent.ACTION_DOWN) return
        if (event.repeatCount > 0) return
        if (isGamepadOrJoystick(event)) return

        when (event.keyCode) {
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            -> play(enterSoundId)

            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_BUTTON_A,
            -> play(optionSoundId)
        }
    }

    private fun play(soundId: Int) {
        if (soundId == 0) return
        val pool = soundPool ?: return

        val now = SystemClock.uptimeMillis()
        if (now - lastPlayUptimeMs < MIN_INTERVAL_MS) return
        lastPlayUptimeMs = now

        try {
            // Con MAX_STREAMS bajo, un stream viejo se corta solo si hace falta.
            pool.play(soundId, UI_VOLUME, UI_VOLUME, /* priority */ 1, /* loop */ 0, 1f)
        } catch (e: Exception) {
            Log.e(TAG, "SoundPool.play falló: ${e.message}", e)
        }
    }

    private fun isGamepadOrJoystick(event: KeyEvent): Boolean {
        val source = event.source
        if (source and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD) return true
        if (source and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK) return true
        return false
    }

    companion object {
        private const val TAG = "UiDpadSounds"
        private const val OPTION_ASSET = "flutter_assets/assets/music/option.wav"
        private const val ENTER_ASSET = "flutter_assets/assets/music/enter.wav"
        private const val UI_VOLUME = 0.18f
        /** Evita acumular clicks al spamear D-pad. */
        private const val MAX_STREAMS = 2
        private const val MIN_INTERVAL_MS = 45L
    }
}
