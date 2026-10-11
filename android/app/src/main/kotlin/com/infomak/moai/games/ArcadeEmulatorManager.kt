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

    val isRunningEmulation: Boolean
        get() = isRunning

    private val playerDeviceMap = mutableMapOf<Int, Int>()
    private var p1Mask: Int = 0
    private var p2Mask: Int = 0

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
                val player = call.argument<Int>("player") ?: 0
                if (player == 0) {
                    currentInputMask = mask
                    p1Mask = mask
                } else {
                    p2Mask = mask
                }
                nativeSendPlayerInputMask(player, mask)
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
        mainHandler.post {
            detectAndAssignConnectedGamepads()
        }
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

    /** Pre-detecta mandos físicos conectados (USB/Bluetooth) y los asigna automáticamente a Jugador 1 y Jugador 2 */
    fun detectAndAssignConnectedGamepads() {
        val inputManager = context.getSystemService(Context.INPUT_SERVICE) as? android.hardware.input.InputManager
        val deviceIds = inputManager?.inputDeviceIds ?: android.view.InputDevice.getDeviceIds()
        var nextPlayer = 0
        for (id in deviceIds) {
            val device = android.view.InputDevice.getDevice(id) ?: continue
            if (device.isVirtual) continue
            val sources = device.sources
            val isGamepad = (sources and android.view.InputDevice.SOURCE_GAMEPAD == android.view.InputDevice.SOURCE_GAMEPAD) ||
                            (sources and android.view.InputDevice.SOURCE_JOYSTICK == android.view.InputDevice.SOURCE_JOYSTICK)
            if (isGamepad && !playerDeviceMap.containsKey(id)) {
                playerDeviceMap[id] = nextPlayer
                android.util.Log.i("ArcadeEmulatorManager", "Pre-asignado mando físico id=$id (${device.name}) a Jugador ${nextPlayer + 1}")
                val playerAssigned = nextPlayer
                channel.invokeMethod("onGamepadAssigned", mapOf("deviceId" to id, "player" to playerAssigned, "name" to device.name))
                nextPlayer++
                if (nextPlayer >= 2) break
            }
        }
    }

    private fun stopEmulation() {
        isRunning = false
        isPaused = false
        currentRomPath = null
        playerDeviceMap.clear()
        p1Mask = 0
        p2Mask = 0
        nativeStop()
    }

    fun handleKeyEvent(event: android.view.KeyEvent): Boolean {
        if (!isRunning) return false

        val isDown = event.action == android.view.KeyEvent.ACTION_DOWN
        val isUp = event.action == android.view.KeyEvent.ACTION_UP
        if (!isDown && !isUp) return false

        var bit = 0
        when (event.keyCode) {
            // D-Pad y Direcciones
            android.view.KeyEvent.KEYCODE_DPAD_UP, android.view.KeyEvent.KEYCODE_BUTTON_11 -> bit = 1 shl 0
            android.view.KeyEvent.KEYCODE_DPAD_DOWN, android.view.KeyEvent.KEYCODE_BUTTON_12 -> bit = 1 shl 1
            android.view.KeyEvent.KEYCODE_DPAD_LEFT, android.view.KeyEvent.KEYCODE_BUTTON_13 -> bit = 1 shl 2
            android.view.KeyEvent.KEYCODE_DPAD_RIGHT, android.view.KeyEvent.KEYCODE_BUTTON_14 -> bit = 1 shl 3

            // COIN / SELECT y START
            android.view.KeyEvent.KEYCODE_BUTTON_SELECT, android.view.KeyEvent.KEYCODE_BUTTON_8 -> bit = 1 shl 4
            android.view.KeyEvent.KEYCODE_BUTTON_START, android.view.KeyEvent.KEYCODE_BUTTON_7 -> bit = 1 shl 5

            // Ataques Puño (CPS-2: LP, MP, HP)
            android.view.KeyEvent.KEYCODE_BUTTON_X, android.view.KeyEvent.KEYCODE_BUTTON_3 -> bit = 1 shl 6
            android.view.KeyEvent.KEYCODE_BUTTON_Y, android.view.KeyEvent.KEYCODE_BUTTON_4 -> bit = 1 shl 7
            android.view.KeyEvent.KEYCODE_BUTTON_R1, android.view.KeyEvent.KEYCODE_BUTTON_L1,
            android.view.KeyEvent.KEYCODE_BUTTON_Z, android.view.KeyEvent.KEYCODE_BUTTON_5 -> bit = 1 shl 8

            // Ataques Patada (CPS-2: LK, MK, HK)
            android.view.KeyEvent.KEYCODE_BUTTON_A, android.view.KeyEvent.KEYCODE_BUTTON_1 -> bit = 1 shl 9
            android.view.KeyEvent.KEYCODE_BUTTON_B, android.view.KeyEvent.KEYCODE_BUTTON_2 -> bit = 1 shl 10
            android.view.KeyEvent.KEYCODE_BUTTON_R2, android.view.KeyEvent.KEYCODE_BUTTON_L2,
            android.view.KeyEvent.KEYCODE_BUTTON_C, android.view.KeyEvent.KEYCODE_BUTTON_6 -> bit = 1 shl 11
        }

        // Si la tecla no es un control de juego (ej. Back, Volumen, etc.), NO asignar mando ni consumir
        if (bit == 0) return false

        val deviceId = event.deviceId
        // Asignar jugador dinámicamente si no fue pre-asignado
        if (!playerDeviceMap.containsKey(deviceId)) {
            val assignedPlayer = if (!playerDeviceMap.containsValue(0)) 0 else if (!playerDeviceMap.containsValue(1)) 1 else 0
            playerDeviceMap[deviceId] = assignedPlayer
            android.util.Log.i("ArcadeEmulatorManager", "Mando físico deviceId=$deviceId asignado a Jugador ${assignedPlayer + 1}")
            channel.invokeMethod("onGamepadAssigned", mapOf("deviceId" to deviceId, "player" to assignedPlayer))
        }

        val player = playerDeviceMap[deviceId] ?: 0

        if (player == 0) {
            p1Mask = if (isDown) (p1Mask or bit) else (p1Mask and bit.inv())
            nativeSendPlayerInputMask(0, p1Mask)
            if ((p1Mask and (1 shl 4)) != 0 && (p1Mask and (1 shl 5)) != 0) {
                channel.invokeMethod("onRequestExitGame", null)
            }
        } else {
            p2Mask = if (isDown) (p2Mask or bit) else (p2Mask and bit.inv())
            nativeSendPlayerInputMask(1, p2Mask)
            if ((p2Mask and (1 shl 4)) != 0 && (p2Mask and (1 shl 5)) != 0) {
                channel.invokeMethod("onRequestExitGame", null)
            }
        }
        return true
    }

    fun handleGenericMotionEvent(event: android.view.MotionEvent): Boolean {
        if (!isRunning) return false
        val sources = event.source
        val isJoystickOrGamepad = (sources and android.view.InputDevice.SOURCE_CLASS_JOYSTICK != 0) ||
                                  (sources and android.view.InputDevice.SOURCE_GAMEPAD != 0) ||
                                  (sources and android.view.InputDevice.SOURCE_JOYSTICK != 0)
        if (!isJoystickOrGamepad) return false

        val deviceId = event.deviceId
        if (!playerDeviceMap.containsKey(deviceId)) {
            val assignedPlayer = if (!playerDeviceMap.containsValue(0)) 0 else if (!playerDeviceMap.containsValue(1)) 1 else 0
            playerDeviceMap[deviceId] = assignedPlayer
            channel.invokeMethod("onGamepadAssigned", mapOf("deviceId" to deviceId, "player" to assignedPlayer))
        }
        val player = playerDeviceMap[deviceId] ?: 0

        val x = event.getAxisValue(android.view.MotionEvent.AXIS_HAT_X).let {
            if (it != 0f) it else event.getAxisValue(android.view.MotionEvent.AXIS_X)
        }
        val y = event.getAxisValue(android.view.MotionEvent.AXIS_HAT_Y).let {
            if (it != 0f) it else event.getAxisValue(android.view.MotionEvent.AXIS_Y)
        }

        var dirMask = 0
        if (y < -0.4f) dirMask = dirMask or (1 shl 0) // UP
        if (y > 0.4f)  dirMask = dirMask or (1 shl 1) // DOWN
        if (x < -0.4f) dirMask = dirMask or (1 shl 2) // LEFT
        if (x > 0.4f)  dirMask = dirMask or (1 shl 3) // RIGHT

        // Gatillos analógicos (R2 / L2)
        val rTrigger = maxOf(event.getAxisValue(android.view.MotionEvent.AXIS_RTRIGGER), event.getAxisValue(android.view.MotionEvent.AXIS_GAS))
        val lTrigger = maxOf(event.getAxisValue(android.view.MotionEvent.AXIS_LTRIGGER), event.getAxisValue(android.view.MotionEvent.AXIS_BRAKE))
        val triggerPressed = (rTrigger > 0.5f || lTrigger > 0.5f)

        if (player == 0) {
            p1Mask = (p1Mask and 0xFFF0) or dirMask
            if (triggerPressed) {
                p1Mask = p1Mask or (1 shl 11)
            }
            nativeSendPlayerInputMask(0, p1Mask)
        } else {
            p2Mask = (p2Mask and 0xFFF0) or dirMask
            if (triggerPressed) {
                p2Mask = p2Mask or (1 shl 11)
            }
            nativeSendPlayerInputMask(1, p2Mask)
        }
        return true
    }

    // --- Native JNI declarations ---
    private external fun nativeInitDirectories(systemDir: String, saveDir: String)
    private external fun nativeSetCustomCorePath(path: String)
    private external fun nativeSetSurface(surface: Surface?)
    private external fun nativeSetSurfaceSize(width: Int, height: Int)
    private external fun nativeLoadRom(path: String)
    private external fun nativeSendInputMask(mask: Int)
    private external fun nativeSendPlayerInputMask(player: Int, mask: Int)
    private external fun nativePause()
    private external fun nativeResume()
    private external fun nativeReset()
    private external fun nativeStop()
}
