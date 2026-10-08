package com.infomak.moai.games

import android.content.Context
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ArcadeEmulatorManager(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.infomak.moai/arcade_channel")
    private var activeSurface: Surface? = null
    private var isInitialized = false
    private var isRunning = false
    private var isPaused = false
    private var currentRomPath: String? = null
    private var currentInputMask: Int = 0

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeEmulator" -> {
                val success = initializeNativeEngine()
                result.success(success)
            }
            "loadRom" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_PATH", "La ruta de la ROM no puede ser nula", null)
                    return
                }
                val success = loadRomFile(path)
                result.success(success)
            }
            "sendInputState" -> {
                val mask = call.argument<Int>("mask") ?: 0
                currentInputMask = mask
                nativeSendInputMask(mask)
                result.success(true)
            }
            "pause" -> {
                isPaused = true
                nativePause()
                result.success(true)
            }
            "resume" -> {
                isPaused = false
                nativeResume()
                result.success(true)
            }
            "reset" -> {
                nativeReset()
                result.success(true)
            }
            "stop" -> {
                stopEmulation()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun onSurfaceCreated(surface: Surface) {
        activeSurface = surface
        nativeSetSurface(surface)
    }

    fun onSurfaceChanged(surface: Surface, width: Int, height: Int) {
        activeSurface = surface
        nativeSetSurfaceSize(width, height)
    }

    fun onSurfaceDestroyed() {
        activeSurface = null
        nativeSetSurface(null)
    }

    private fun initializeNativeEngine(): Boolean {
        return try {
            // Intentar cargar la librería nativa si existe (ej: libfbneo.so / libarcade_runner.so)
            try {
                System.loadLibrary("arcade_runner")
            } catch (e: UnsatisfiedLinkError) {
                // Si aún no está compilada la lib C++, marcamos preparado para PoC
            }
            isInitialized = true
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun loadRomFile(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            channel.invokeMethod("onEmulatorError", "El archivo de ROM no existe en: $path")
            return false
        }

        currentRomPath = path
        isRunning = true
        isPaused = false
        nativeLoadRom(path)
        return true
    }

    private fun stopEmulation() {
        isRunning = false
        isPaused = false
        currentRomPath = null
        nativeStop()
    }

    // --- Stubs Native / JNI ---
    private fun nativeSetSurface(surface: Surface?) {}
    private fun nativeSetSurfaceSize(width: Int, height: Int) {}
    private fun nativeLoadRom(path: String) {}
    private fun nativeSendInputMask(mask: Int) {}
    private fun nativePause() {}
    private fun nativeResume() {}
    private fun nativeReset() {}
    private fun nativeStop() {}
}
