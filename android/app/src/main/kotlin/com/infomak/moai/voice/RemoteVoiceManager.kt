package com.infomak.moai.voice

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File

/**
 * Gestor nativo para la prueba de captura de voz del control remoto en Android TV.
 *
 * Utiliza AudioSource.VOICE_RECOGNITION para despertar el enlace Voice-over-BLE del control remoto
 * y almacena la muestra de audio en formato AAC (.m4a) a 16 kHz Mono.
 * Aplica normalización y ganancia digital (+18 dB vía LoudnessEnhancer) al reproducir en la TV.
 */
class RemoteVoiceManager(private val activity: Activity) {

    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentOutputFile: File? = null

    var isRecording: Boolean = false
        private set

    var isPlaying: Boolean = false
        private set

    fun checkHardware(): Map<String, Any> {
        val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val deviceList = mutableListOf<Map<String, Any>>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            for (dev in devices) {
                val typeName = when (dev.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth SCO (Control Remoto)"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth A2DP"
                    AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Micrófono Integrado"
                    AudioDeviceInfo.TYPE_USB_DEVICE -> "Dispositivo USB"
                    AudioDeviceInfo.TYPE_USB_HEADSET -> "Auricular USB"
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Auricular con cable"
                    AudioDeviceInfo.TYPE_BUS -> "Bus de Audio"
                    else -> "Tipo ${dev.type}"
                }
                deviceList.add(
                    mapOf(
                        "name" to (dev.productName?.toString() ?: "Dispositivo"),
                        "type" to dev.type,
                        "typeName" to typeName,
                    )
                )
            }
        }
        val hasMicFeature = activity.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)
        return mapOf(
            "hasMicFeature" to hasMicFeature,
            "devices" to deviceList,
        )
    }

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun requestPermission() {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            1001,
        )
    }

    fun startRecording(): Map<String, Any> {
        if (isRecording) {
            return mapOf("success" to false, "error" to "Ya hay una grabación en curso")
        }

        stopPlayback()

        val outputFile = File(activity.cacheDir, "test_remote_voice.m4a")
        if (outputFile.exists()) {
            outputFile.delete()
        }
        currentOutputFile = outputFile

        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(activity)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        return try {
            recorder.apply {
                // CLAVE PARA ANDROID TV: VOICE_RECOGNITION (6) envía MIC_OPEN al control BLE
                setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000)
                setAudioChannels(1)
                setAudioEncodingBitRate(64000)
                setOutputFile(outputFile.absolutePath)
                prepare()
                start()
            }
            mediaRecorder = recorder
            isRecording = true
            Log.i("RemoteVoiceManager", "Grabación iniciada en: ${outputFile.absolutePath}")
            mapOf("success" to true, "path" to outputFile.absolutePath)
        } catch (e: Exception) {
            Log.e("RemoteVoiceManager", "Error al iniciar grabación", e)
            try { recorder.release() } catch (_: Exception) {}
            mediaRecorder = null
            isRecording = false
            mapOf("success" to false, "error" to (e.message ?: "Error desconocido"))
        }
    }

    fun stopRecording(): Map<String, Any> {
        val recorder = mediaRecorder ?: return mapOf(
            "success" to false,
            "error" to "No hay grabación activa",
        )
        val file = currentOutputFile ?: return mapOf(
            "success" to false,
            "error" to "Archivo de salida nulo",
        )

        return try {
            recorder.stop()
            recorder.release()
            mediaRecorder = null
            isRecording = false
            Log.i("RemoteVoiceManager", "Grabación finalizada. Tamaño: ${file.length()} bytes")
            mapOf(
                "success" to true,
                "path" to file.absolutePath,
                "sizeBytes" to file.length(),
            )
        } catch (e: Exception) {
            Log.e("RemoteVoiceManager", "Error al detener grabación", e)
            try { recorder.release() } catch (_: Exception) {}
            mediaRecorder = null
            isRecording = false
            mapOf("success" to false, "error" to (e.message ?: "Error al detener"))
        }
    }

    fun playRecording(onComplete: () -> Unit): Map<String, Any> {
        val file = currentOutputFile ?: File(activity.cacheDir, "test_remote_voice.m4a")
        if (!file.exists() || file.length() == 0L) {
            return mapOf("success" to false, "error" to "No hay audio grabado disponible")
        }
        return playAudio(file.absolutePath, onComplete)
    }

    fun playAudio(source: String, onComplete: () -> Unit): Map<String, Any> {
        if (source.isBlank()) {
            return mapOf("success" to false, "error" to "Fuente de audio vacía")
        }

        stopPlayback()

        return try {
            val player = MediaPlayer().apply {
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
                setAudioAttributes(audioAttributes)
                setDataSource(source)
                prepare()
                setOnCompletionListener {
                    stopPlayback()
                    onComplete()
                }
            }

            try {
                loudnessEnhancer = LoudnessEnhancer(player.audioSessionId).apply {
                    setTargetGain(1800) // +18 dB boost para igualar el nivel de la TV
                    enabled = true
                }
            } catch (e: Exception) {
                Log.w("RemoteVoiceManager", "LoudnessEnhancer no disponible: ${e.message}")
            }

            player.start()
            mediaPlayer = player
            isPlaying = true
            mapOf("success" to true, "durationMs" to player.duration)
        } catch (e: Exception) {
            Log.e("RemoteVoiceManager", "Error al reproducir audio: $source", e)
            stopPlayback()
            mapOf("success" to false, "error" to (e.message ?: "Error al reproducir"))
        }
    }

    fun stopPlayback() {
        try {
            loudnessEnhancer?.enabled = false
            loudnessEnhancer?.release()
        } catch (_: Exception) {}
        loudnessEnhancer = null

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null
        isPlaying = false
    }

    fun release() {
        if (isRecording) {
            try { mediaRecorder?.stop() } catch (_: Exception) {}
        }
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder = null
        stopPlayback()
    }
}
