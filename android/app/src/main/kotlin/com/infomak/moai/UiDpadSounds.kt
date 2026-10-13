package com.infomak.moai

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent

/**
 * Clicks de UI solo para control D-pad / teclado TV.
 * Ignora gamepad y joystick.
 *
 * Reproduce en STREAM_MUSIC (audible en Android TV) pero **sin** pedir
 * audio focus, para no bajar el volumen del reproductor.
 */
class UiDpadSounds(private val context: Context) {
    @Volatile
    private var enabled = true

    fun init() {
        for (path in listOf(OPTION_ASSET, ENTER_ASSET)) {
            try {
                context.assets.openFd(path).close()
                Log.i(TAG, "Asset OK: $path")
            } catch (e: Exception) {
                Log.e(TAG, "Asset NO encontrado: $path (${e.message})")
            }
        }
    }

    fun release() {}

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
            -> playAsset(ENTER_ASSET) // navegación

            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_BUTTON_A,
            -> playAsset(OPTION_ASSET) // confirmar
        }
    }

    private fun playAsset(assetPath: String) {
        try {
            val afd = context.assets.openFd(assetPath)
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            player.isLooping = false
            player.setVolume(UI_VOLUME, UI_VOLUME)
            player.setOnCompletionListener { mp ->
                try {
                    mp.release()
                } catch (_: Exception) {
                }
            }
            player.setOnErrorListener { mp, what, extra ->
                Log.e(TAG, "MediaPlayer error what=$what extra=$extra path=$assetPath")
                try {
                    mp.release()
                } catch (_: Exception) {
                }
                true
            }
            player.prepare()
            player.start()
            Log.d(TAG, "Playing $assetPath vol=$UI_VOLUME")
        } catch (e: Exception) {
            Log.e(TAG, "No se pudo reproducir $assetPath: ${e.message}", e)
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
    }
}
