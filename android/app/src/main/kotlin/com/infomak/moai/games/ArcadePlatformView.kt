package com.infomak.moai.games

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.platform.PlatformView

class ArcadePlatformView(
    context: Context,
    private val viewId: Int,
    creationParams: Map<String, Any?>?,
    private val emulatorManager: ArcadeEmulatorManager
) : PlatformView, SurfaceHolder.Callback {

    private val surfaceView: SurfaceView = SurfaceView(context)

    init {
        surfaceView.holder.addCallback(this)
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        emulatorManager.onSurfaceDestroyed()
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        emulatorManager.onSurfaceCreated(holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        emulatorManager.onSurfaceChanged(holder.surface, width, height)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        emulatorManager.onSurfaceDestroyed()
    }
}
