#include <jni.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <dlfcn.h>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <atomic>
#include <mutex>
#include "libretro.h"

#define LOG_TAG "ArcadeRunner"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static ANativeWindow* g_native_window = nullptr;
static std::mutex g_window_mutex;

static void* g_core_handle = nullptr;
static retro_init_t core_retro_init = nullptr;
static retro_deinit_t core_retro_deinit = nullptr;
static retro_load_game_t core_retro_load_game = nullptr;
static retro_unload_game_t core_retro_unload_game = nullptr;
static retro_run_t core_retro_run = nullptr;
static retro_reset_t core_retro_reset = nullptr;
static retro_set_environment_t core_retro_set_environment = nullptr;
static retro_set_video_refresh_t core_retro_set_video_refresh = nullptr;
static retro_set_audio_sample_t core_retro_set_audio_sample = nullptr;
static retro_set_audio_sample_batch_t core_retro_set_audio_sample_batch = nullptr;
static retro_set_input_poll_t core_retro_set_input_poll = nullptr;
static retro_set_input_state_t core_retro_set_input_state = nullptr;
static retro_get_system_av_info_t core_retro_get_system_av_info = nullptr;

static std::atomic<uint16_t> g_input_bitmask{0};
static std::atomic<bool> g_is_running{false};
static std::atomic<bool> g_is_paused{false};
static std::thread g_emu_thread;

static enum retro_pixel_format g_pixel_format = RETRO_PIXEL_FORMAT_RGB565;

// Callback de entorno Libretro
static bool core_environment_cb(unsigned cmd, void *data) {
   switch (cmd) {
      case 10: // RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
         if (data) {
            g_pixel_format = *static_cast<enum retro_pixel_format*>(data);
            LOGI("Core pixel format set to: %d", g_pixel_format);
         }
         return true;
      default:
         return false;
   }
}

// Callback de video Libretro -> ANativeWindow
static void core_video_refresh_cb(const void *data, unsigned width, unsigned height, size_t pitch) {
   if (!data || width == 0 || height == 0) return;

   std::lock_guard<std::mutex> lock(g_window_mutex);
   if (!g_native_window) return;

   int32_t format = WINDOW_FORMAT_RGB_565;
   if (g_pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) {
      format = WINDOW_FORMAT_RGBA_8888;
   }

   ANativeWindow_setBuffersGeometry(g_native_window, width, height, format);

   ANativeWindow_Buffer buffer;
   if (ANativeWindow_lock(g_native_window, &buffer, nullptr) < 0) {
      return;
   }

   const uint8_t* src = static_cast<const uint8_t*>(data);
   uint8_t* dst = static_cast<uint8_t*>(buffer.bits);

   size_t src_line_bytes = pitch;
   size_t dst_line_bytes = buffer.stride * (format == WINDOW_FORMAT_RGBA_8888 ? 4 : 2);

   for (unsigned y = 0; y < height; ++y) {
      std::memcpy(dst + y * dst_line_bytes, src + y * src_line_bytes, src_line_bytes);
   }

   ANativeWindow_unlockAndPost(g_native_window);
}

static void core_audio_sample_cb(int16_t left, int16_t right) {}

static size_t core_audio_sample_batch_cb(const int16_t *data, size_t frames) {
   return frames;
}

static void core_input_poll_cb() {}

static int16_t core_input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
   if (port != 0 || device != RETRO_DEVICE_JOYPAD) return 0;

   uint16_t mask = g_input_bitmask.load();

   // Mapeo bitmask Flutter -> Libretro Joypad IDs
   // Bitmask Flutter:
   // 0: UP, 1: DOWN, 2: LEFT, 3: RIGHT, 4: COIN, 5: START
   // 6: LP, 7: MP, 8: HP, 9: LK, 10: MK, 11: HK
   switch (id) {
      case RETRO_DEVICE_ID_JOYPAD_UP:     return (mask & (1 << 0)) ? 1 : 0;
      case RETRO_DEVICE_ID_JOYPAD_DOWN:   return (mask & (1 << 1)) ? 1 : 0;
      case RETRO_DEVICE_ID_JOYPAD_LEFT:   return (mask & (1 << 2)) ? 1 : 0;
      case RETRO_DEVICE_ID_JOYPAD_RIGHT:  return (mask & (1 << 3)) ? 1 : 0;
      case RETRO_DEVICE_ID_JOYPAD_SELECT: return (mask & (1 << 4)) ? 1 : 0;
      case RETRO_DEVICE_ID_JOYPAD_START:  return (mask & (1 << 5)) ? 1 : 0;

      // Ataques CPS-2
      case RETRO_DEVICE_ID_JOYPAD_Y: return (mask & (1 << 6)) ? 1 : 0; // Low Punch
      case RETRO_DEVICE_ID_JOYPAD_X: return (mask & (1 << 7)) ? 1 : 0; // Medium Punch
      case RETRO_DEVICE_ID_JOYPAD_L: return (mask & (1 << 8)) ? 1 : 0; // Heavy Punch

      case RETRO_DEVICE_ID_JOYPAD_B: return (mask & (1 << 9)) ? 1 : 0;  // Low Kick
      case RETRO_DEVICE_ID_JOYPAD_A: return (mask & (1 << 10)) ? 1 : 0; // Medium Kick
      case RETRO_DEVICE_ID_JOYPAD_R: return (mask & (1 << 11)) ? 1 : 0; // Heavy Kick
      default: return 0;
   }
}

static void emulation_loop() {
   LOGI("Loop de emulación iniciado.");
   while (g_is_running.load()) {
      if (!g_is_paused.load() && core_retro_run) {
         core_retro_run();
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60 FPS
   }
   LOGI("Loop de emulación finalizado.");
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeSetSurface(JNIEnv *env, jobject thiz, jobject surface) {
   std::lock_guard<std::mutex> lock(g_window_mutex);
   if (g_native_window) {
      ANativeWindow_release(g_native_window);
      g_native_window = nullptr;
   }
   if (surface) {
      g_native_window = ANativeWindow_fromSurface(env, surface);
      LOGI("ANativeWindow configurado con éxito.");
   }
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeSetSurfaceSize(JNIEnv *env, jobject thiz, jint width, jint height) {
   LOGI("Superficie redimensionada: %dx%d", width, height);
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeLoadRom(JNIEnv *env, jobject thiz, jstring path_jstr) {
   const char *path = env->GetStringUTFChars(path_jstr, nullptr);
   LOGI("Solicitando cargar ROM: %s", path);

   // Detener loop anterior si existía
   g_is_running.store(false);
   if (g_emu_thread.joinable()) {
      g_emu_thread.join();
   }

   if (g_core_handle && core_retro_load_game) {
      struct retro_game_info game_info = { path, nullptr, 0, nullptr };
      if (core_retro_load_game(&game_info)) {
         LOGI("ROM cargada exitosamente en el core.");
         g_is_running.store(true);
         g_is_paused.store(false);
         g_emu_thread = std::thread(emulation_loop);
      } else {
         LOGE("El core no pudo cargar la ROM.");
      }
   }

   env->ReleaseStringUTFChars(path_jstr, path);
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeSendInputMask(JNIEnv *env, jobject thiz, jint mask) {
   g_input_bitmask.store(static_cast<uint16_t>(mask));
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativePause(JNIEnv *env, jobject thiz) {
   g_is_paused.store(true);
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeResume(JNIEnv *env, jobject thiz) {
   g_is_paused.store(false);
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeReset(JNIEnv *env, jobject thiz) {
   if (core_retro_reset) {
      core_retro_reset();
   }
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeStop(JNIEnv *env, jobject thiz) {
   g_is_running.store(false);
   if (g_emu_thread.joinable()) {
      g_emu_thread.join();
   }
   if (core_retro_unload_game) {
      core_retro_unload_game();
   }
}

}
