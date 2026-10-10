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

    companion object {
        init {
            try {
                System.loadLibrary("arcade_runner")
                android.util.Log.i("ArcadeEmulatorManager", "libarcade_runner.so cargada con éxito")
            } catch (e: Throwable) {
                android.util.Log.e("ArcadeEmulatorManager", "Error al cargar libarcade_runner.so: ${e.message}")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeEmulator" -> {
                val success = initializeNativeEngine()
                result.success(success)
            }
            "setCustomCorePath" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    nativeSetCustomCorePath(path)
                    result.success(true)
                } else {
                    result.error("INVALID_PATH", "Ruta de core nula", null)
                }
            }
            "loadRom" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_PATH", "La ruta de la ROM no puede ser nula", null)
                    return
                }
                loadRomFile(path) { success ->
                    result.success(success)
                }
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
            "getRomDirectory" -> {
                result.success(context.filesDir.absolutePath)
            }
            "deleteRom" -> {
                val name = call.argument<String>("name")
                if (name != null) {
                    val file = File(context.filesDir, name)
                    val deleted = if (file.exists()) file.delete() else false
                    result.success(deleted)
                } else {
                    result.error("INVALID_NAME", "Nombre no provisto", null)
                }
            }
            "getInstalledRoms" -> {
                val files = context.filesDir.listFiles { _, name -> name.endsWith(".zip") }
                val list = files?.map { f ->
                    mapOf(
                        "filename" to f.name,
                        "path" to f.absolutePath,
                        "sizeBytes" to f.length()
                    )
                } ?: emptyList<Map<String, Any>>()
                result.success(list)
            }
            "getConnectedGamepads" -> {
                val inputManager = context.getSystemService(Context.INPUT_SERVICE) as? android.hardware.input.InputManager
                val deviceIds = inputManager?.inputDeviceIds ?: android.view.InputDevice.getDeviceIds()
                val gamepads = mutableListOf<Map<String, Any>>()
                for (id in deviceIds) {
                    val device = android.view.InputDevice.getDevice(id) ?: continue
                    val sources = device.sources
                    val isGamepad = (sources and android.view.InputDevice.SOURCE_GAMEPAD == android.view.InputDevice.SOURCE_GAMEPAD) ||
                                    (sources and android.view.InputDevice.SOURCE_JOYSTICK == android.view.InputDevice.SOURCE_JOYSTICK)
                    if (isGamepad && !device.isVirtual) {
                        gamepads.add(
                            mapOf(
                                "id" to device.id,
                                "name" to device.name,
                                "descriptor" to device.descriptor,
                                "vendorId" to device.vendorId,
                                "productId" to device.productId,
                                "isExternal" to device.isExternal
                            )
                        )
                    }
                }
                result.success(gamepads)
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
            val dirPath = context.filesDir.absolutePath
            nativeInitDirectories(dirPath, dirPath)
            isInitialized = true
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun loadRomFile(path: String, onComplete: (Boolean) -> Unit) {
        var file = File(path)
        if (!file.exists()) {
            val internal = File(context.filesDir, file.name)
            if (internal.exists()) {
                file = internal
            }
        }

        // Si el archivo está en /sdcard/Download pero no en filesDir, intentar copiarlo para acceso nativo directo
        val targetInFiles = File(context.filesDir, file.name)
        if (file.exists() && file.absolutePath != targetInFiles.absolutePath && !targetInFiles.exists()) {
            try {
                file.copyTo(targetInFiles, overwrite = true)
                file = targetInFiles
                android.util.Log.i("ArcadeEmulatorManager", "ROM copiada a almacenamiento interno: ${file.absolutePath}")
            } catch (e: Exception) {
                android.util.Log.w("ArcadeEmulatorManager", "No se pudo copiar a filesDir: ${e.message}")
            }
        } else if (targetInFiles.exists()) {
            file = targetInFiles
        }

        if (!file.exists()) {
            channel.invokeMethod("onEmulatorError", "El archivo de ROM no existe en: $path")
            onComplete(false)
            return
        }

        val resolvedPath = file.absolutePath
        currentRomPath = resolvedPath
        isRunning = true
        isPaused = false
        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        Thread({
            try {
                nativeLoadRom(resolvedPath)
                mainHandler.post {
                    onComplete(true)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    channel.invokeMethod("onEmulatorError", "Error al cargar ROM: ${e.message}")
                    onComplete(false)
                }
            }
        }, "ArcadeRomLoader").start()
    }

    private fun stopEmulation() {
        isRunning = false
        isPaused = false
        currentRomPath = null
        nativeStop()
    }

    // --- Native JNI declarations ---
    private external fun nativeInitDirectories(systemDir: String, saveDir: String)
    private external fun nativeSetCustomCorePath(path: String)
    private external fun nativeSetSurface(surface: Surface?)
    private external fun nativeSetSurfaceSize(width: Int, height: Int)
    private external fun nativeLoadRom(path: String)
    private external fun nativeSendInputMask(mask: Int)
    private external fun nativePause()
    private external fun nativeResume()
    private external fun nativeReset()
    private external fun nativeStop()
}
