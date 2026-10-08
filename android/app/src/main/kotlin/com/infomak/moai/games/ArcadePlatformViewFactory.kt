package com.infomak.moai.games

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ArcadePlatformViewFactory(
    private val emulatorManager: ArcadeEmulatorManager
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any?>
        return ArcadePlatformView(context, viewId, creationParams, emulatorManager)
    }
}
