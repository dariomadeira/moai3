#include <jni.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <aaudio/AAudio.h>
#include <dlfcn.h>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <atomic>
#include <mutex>
#include <string>
#include "libretro.h"

#define LOG_TAG "ArcadeRunner"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static ANativeWindow* g_native_window = nullptr;
static std::mutex g_window_mutex;

static AAudioStream* g_audio_stream = nullptr;
static std::mutex g_audio_mutex;

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
static std::string g_system_dir = "/sdcard";
static std::string g_save_dir = "/sdcard";

static unsigned g_last_width = 0;
static unsigned g_last_height = 0;
static int32_t g_last_format = 0;

// Callback de entorno Libretro
static bool core_environment_cb(unsigned cmd, void *data) {
   switch (cmd) {
      case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
         if (data) {
            g_pixel_format = *static_cast<enum retro_pixel_format*>(data);
            LOGI("Core pixel format set to: %d", g_pixel_format);
         }
         return true;
      case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
         if (data) {
            *static_cast<const char**>(data) = g_system_dir.c_str();
            LOGI("FBNeo requested system directory: %s", g_system_dir.c_str());
         }
         return true;
      case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
         if (data) {
            *static_cast<const char**>(data) = g_save_dir.c_str();
            LOGI("FBNeo requested save directory: %s", g_save_dir.c_str());
         }
         return true;
      case RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY:
         if (data) {
            *static_cast<const char**>(data) = g_system_dir.c_str();
            LOGI("FBNeo requested content directory: %s", g_system_dir.c_str());
         }
         return true;
      case RETRO_ENVIRONMENT_GET_CAN_DUPLICATE_FLAGS:
         if (data) {
            *static_cast<bool*>(data) = true;
         }
         return true;
      case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
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
   if (pitch == 0) {
      pitch = width * (format == WINDOW_FORMAT_RGBA_8888 ? 4 : 2);
   }

   if (width != g_last_width || height != g_last_height || format != g_last_format) {
      ANativeWindow_setBuffersGeometry(g_native_window, width, height, format);
      g_last_width = width;
      g_last_height = height;
      g_last_format = format;
   }

   ANativeWindow_Buffer buffer;
   if (ANativeWindow_lock(g_native_window, &buffer, nullptr) < 0) {
      return;
   }

   if (!buffer.bits) {
      ANativeWindow_unlockAndPost(g_native_window);
      return;
   }

   const uint8_t* src = static_cast<const uint8_t*>(data);
   uint8_t* dst = static_cast<uint8_t*>(buffer.bits);
   unsigned render_height = (static_cast<unsigned>(buffer.height) < height && buffer.height > 0)
                               ? static_cast<unsigned>(buffer.height)
                               : height;

   unsigned render_width = (buffer.stride > 0 && static_cast<unsigned>(buffer.stride) < width)
                              ? static_cast<unsigned>(buffer.stride)
                              : width;

   if (format == WINDOW_FORMAT_RGBA_8888 && g_pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) {
      for (unsigned y = 0; y < render_height; ++y) {
         const uint32_t* src_row = reinterpret_cast<const uint32_t*>(src + y * pitch);
         uint32_t* dst_row = reinterpret_cast<uint32_t*>(dst + y * buffer.stride * 4);
         for (unsigned x = 0; x < render_width; ++x) {
            uint32_t pixel = src_row[x];
            uint8_t r = (pixel >> 16) & 0xFF;
            uint8_t g = (pixel >> 8) & 0xFF;
            uint8_t b = pixel & 0xFF;
            dst_row[x] = (0xFF000000) | (b << 16) | (g << 8) | r;
         }
      }
   } else {
      size_t copy_bytes = render_width * (format == WINDOW_FORMAT_RGBA_8888 ? 4 : 2);
      size_t dst_stride_bytes = buffer.stride * (format == WINDOW_FORMAT_RGBA_8888 ? 4 : 2);
      for (unsigned y = 0; y < render_height; ++y) {
         std::memcpy(dst + y * dst_stride_bytes, src + y * pitch, copy_bytes);
      }
   }

   ANativeWindow_unlockAndPost(g_native_window);
}

static std::atomic<double> g_target_fps{60.0};

// Manejo de Audio con AAudio de baja latencia
static void start_aaudio(int32_t sample_rate = 44100) {
   std::lock_guard<std::mutex> lock(g_audio_mutex);
   if (g_audio_stream) return;

   AAudioStreamBuilder *builder = nullptr;
   aaudio_result_t result = AAudio_createStreamBuilder(&builder);
   if (result != AAUDIO_OK || !builder) {
      LOGE("Error creando AAudioStreamBuilder: %s", AAudio_convertResultToText(result));
      return;
   }

   AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_I16);
   AAudioStreamBuilder_setChannelCount(builder, 2); // Estéreo
   AAudioStreamBuilder_setSampleRate(builder, sample_rate > 0 ? sample_rate : 44100);
   AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
   AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_SHARED);
   AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_OUTPUT);

   result = AAudioStreamBuilder_openStream(builder, &g_audio_stream);
   AAudioStreamBuilder_delete(builder);

   if (result != AAUDIO_OK || !g_audio_stream) {
      LOGE("Error abriendo AAudioStream: %s", AAudio_convertResultToText(result));
      g_audio_stream = nullptr;
      return;
   }

   // Incrementar el buffer a 4x ráfagas para evitar vaciado (underflow/choppiness) en Android TV
   int32_t burstSize = AAudioStream_getFramesPerBurst(g_audio_stream);
   if (burstSize > 0) {
      AAudioStream_setBufferSizeInFrames(g_audio_stream, burstSize * 4);
   }

   result = AAudioStream_requestStart(g_audio_stream);
   if (result != AAUDIO_OK) {
      LOGE("Error iniciando AAudioStream: %s", AAudio_convertResultToText(result));
      AAudioStream_close(g_audio_stream);
      g_audio_stream = nullptr;
      return;
   }

   LOGI("AAudioStream iniciado con éxito: %d Hz, 2 canales, burst=%d", sample_rate, burstSize);
}

static void stop_aaudio() {
   std::lock_guard<std::mutex> lock(g_audio_mutex);
   if (g_audio_stream) {
      AAudioStream_requestStop(g_audio_stream);
      AAudioStream_close(g_audio_stream);
      g_audio_stream = nullptr;
      LOGI("AAudioStream detenido y cerrado.");
   }
}

static void core_audio_sample_cb(int16_t left, int16_t right) {
   int16_t buffer[2] = {left, right};
   std::lock_guard<std::mutex> lock(g_audio_mutex);
   if (g_audio_stream) {
      AAudioStream_write(g_audio_stream, buffer, 1, 50000000LL); // 50ms timeout
   }
}

static size_t core_audio_sample_batch_cb(const int16_t *data, size_t frames) {
   if (!data || frames == 0) return 0;
   std::lock_guard<std::mutex> lock(g_audio_mutex);
   if (g_audio_stream) {
      // Escribir muestras PCM con timeout de 100ms (sincronizando audio con velocidad real del juego)
      aaudio_result_t written = AAudioStream_write(g_audio_stream, data, static_cast<int32_t>(frames), 100000000LL);
      if (written < 0) {
         LOGE("AAudioStream_write error: %s", AAudio_convertResultToText(written));
         return frames;
      }
      return static_cast<size_t>(written);
   }
   return frames;
}

static void core_input_poll_cb() {}

static int16_t core_input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id) {
   if (port != 0 || (device & RETRO_DEVICE_MASK) != RETRO_DEVICE_JOYPAD) return 0;

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
   using clock = std::chrono::steady_clock;
   double fps = g_target_fps.load();
   if (fps <= 0.0) fps = 60.0;
   auto frame_duration = std::chrono::duration_cast<clock::duration>(std::chrono::duration<double>(1.0 / fps));

   auto next_frame = clock::now();

   while (g_is_running.load()) {
      if (!g_is_paused.load() && core_retro_run) {
         core_retro_run();
      }

      next_frame += frame_duration;
      auto now = clock::now();
      if (now < next_frame) {
         std::this_thread::sleep_until(next_frame);
      } else {
         // Si hubo lag o desincronización, reajustar el tiempo del siguiente frame
         next_frame = now;
      }
   }
   LOGI("Loop de emulación finalizado.");
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeInitDirectories(JNIEnv *env, jobject thiz, jstring sys_dir, jstring save_dir) {
   if (sys_dir) {
      const char *s = env->GetStringUTFChars(sys_dir, nullptr);
      if (s) {
         g_system_dir = s;
         env->ReleaseStringUTFChars(sys_dir, s);
      }
   }
   if (save_dir) {
      const char *s = env->GetStringUTFChars(save_dir, nullptr);
      if (s) {
         g_save_dir = s;
         env->ReleaseStringUTFChars(save_dir, s);
      }
   }
   LOGI("Directorios inicializados: system=%s, save=%s", g_system_dir.c_str(), g_save_dir.c_str());
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeSetSurface(JNIEnv *env, jobject thiz, jobject surface) {
   std::lock_guard<std::mutex> lock(g_window_mutex);
   if (g_native_window) {
      ANativeWindow_release(g_native_window);
      g_native_window = nullptr;
   }
   if (surface) {
      g_native_window = ANativeWindow_fromSurface(env, surface);
      g_last_width = 0;
      g_last_height = 0;
      g_last_format = 0;
      LOGI("ANativeWindow configurado con éxito.");
   }
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeSetSurfaceSize(JNIEnv *env, jobject thiz, jint width, jint height) {
   LOGI("Superficie redimensionada: %dx%d", width, height);
}

static std::atomic<bool> g_core_initialized{false};

static bool ensure_core_loaded() {
   if (g_core_initialized.load() && g_core_handle) return true;

   if (!g_core_handle) {
      g_core_handle = dlopen("libfbneo.so", RTLD_NOW);
      if (!g_core_handle) {
         const char* err = dlerror();
         LOGI("dlopen(\"libfbneo.so\") falló (%s), intentando dlsym con RTLD_DEFAULT...", err ? err : "desconocido");
         g_core_handle = RTLD_DEFAULT;
      }
   }

   core_retro_init = (retro_init_t)dlsym(g_core_handle, "retro_init");
   core_retro_deinit = (retro_deinit_t)dlsym(g_core_handle, "retro_deinit");
   core_retro_load_game = (retro_load_game_t)dlsym(g_core_handle, "retro_load_game");
   core_retro_unload_game = (retro_unload_game_t)dlsym(g_core_handle, "retro_unload_game");
   core_retro_run = (retro_run_t)dlsym(g_core_handle, "retro_run");
   core_retro_reset = (retro_reset_t)dlsym(g_core_handle, "retro_reset");
   core_retro_set_environment = (retro_set_environment_t)dlsym(g_core_handle, "retro_set_environment");
   core_retro_set_video_refresh = (retro_set_video_refresh_t)dlsym(g_core_handle, "retro_set_video_refresh");
   core_retro_set_audio_sample = (retro_set_audio_sample_t)dlsym(g_core_handle, "retro_set_audio_sample");
   core_retro_set_audio_sample_batch = (retro_set_audio_sample_batch_t)dlsym(g_core_handle, "retro_set_audio_sample_batch");
   core_retro_set_input_poll = (retro_set_input_poll_t)dlsym(g_core_handle, "retro_set_input_poll");
   core_retro_set_input_state = (retro_set_input_state_t)dlsym(g_core_handle, "retro_set_input_state");
   core_retro_get_system_av_info = (retro_get_system_av_info_t)dlsym(g_core_handle, "retro_get_system_av_info");

   if (!core_retro_init || !core_retro_load_game || !core_retro_run) {
      LOGE("Error al vincular símbolos Libretro de libfbneo.so");
      if (g_core_handle && g_core_handle != RTLD_DEFAULT) {
         dlclose(g_core_handle);
      }
      g_core_handle = nullptr;
      return false;
   }

   if (core_retro_set_environment) core_retro_set_environment(core_environment_cb);
   if (core_retro_set_video_refresh) core_retro_set_video_refresh(core_video_refresh_cb);
   if (core_retro_set_audio_sample) core_retro_set_audio_sample(core_audio_sample_cb);
   if (core_retro_set_audio_sample_batch) core_retro_set_audio_sample_batch(core_audio_sample_batch_cb);
   if (core_retro_set_input_poll) core_retro_set_input_poll(core_input_poll_cb);
   if (core_retro_set_input_state) core_retro_set_input_state(core_input_state_cb);

   if (!g_core_initialized.load()) {
      core_retro_init();
      g_core_initialized.store(true);
      LOGI("Core FBNeo cargado e inicializado exitosamente (una sola vez).");
   }
   return true;
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeLoadRom(JNIEnv *env, jobject thiz, jstring path_jstr) {
   const char *path = env->GetStringUTFChars(path_jstr, nullptr);
   LOGI("Solicitando cargar ROM: %s", path);

   if (path) {
      std::string s_path(path);
      size_t last_slash = s_path.find_last_of('/');
      if (last_slash != std::string::npos) {
         g_system_dir = s_path.substr(0, last_slash);
         g_save_dir = g_system_dir;
         LOGI("Directorio del juego configurado a: %s", g_system_dir.c_str());
      }
   }

   // Detener loop anterior si existía
   g_is_running.store(false);
   if (g_emu_thread.joinable()) {
      g_emu_thread.join();
   }
   stop_aaudio();

   if (ensure_core_loaded() && core_retro_load_game) {
      struct retro_game_info game_info = { path, nullptr, 0, nullptr };
      if (core_retro_load_game(&game_info)) {
         LOGI("ROM cargada exitosamente en el core FBNeo.");

         // Obtener tasa de muestreo recomendada por el core o fallback a 44100Hz
         int32_t sample_rate = 44100;
         if (core_retro_get_system_av_info) {
            struct retro_system_av_info av_info;
            std::memset(&av_info, 0, sizeof(av_info));
            core_retro_get_system_av_info(&av_info);
            if (av_info.timing.sample_rate > 0) {
               sample_rate = static_cast<int32_t>(av_info.timing.sample_rate);
               LOGI("Sample rate reportado por Libretro: %d Hz", sample_rate);
            }
            if (av_info.timing.fps > 0) {
               g_target_fps.store(av_info.timing.fps);
               LOGI("FPS reportados por Libretro: %.2f", av_info.timing.fps);
            }
         }

         start_aaudio(sample_rate);

         g_is_running.store(true);
         g_is_paused.store(false);
         g_emu_thread = std::thread(emulation_loop);
      } else {
         LOGE("El core no pudo cargar la ROM: %s", path);
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
   std::lock_guard<std::mutex> lock(g_audio_mutex);
   if (g_audio_stream) {
      AAudioStream_requestPause(g_audio_stream);
   }
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeResume(JNIEnv *env, jobject thiz) {
   g_is_paused.store(false);
   std::lock_guard<std::mutex> lock(g_audio_mutex);
   if (g_audio_stream) {
      AAudioStream_requestStart(g_audio_stream);
   }
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeReset(JNIEnv *env, jobject thiz) {
   if (core_retro_reset) {
      core_retro_reset();
   }
}

JNIEXPORT void JNICALL
Java_com_infomak_moai_games_ArcadeEmulatorManager_nativeStop(JNIEnv *env, jobject thiz) {
   LOGI("Deteniendo emulación Arcade...");
   g_is_running.store(false);
   if (g_emu_thread.joinable()) {
      g_emu_thread.join();
   }
   stop_aaudio();

   if (core_retro_unload_game) {
      core_retro_unload_game();
      LOGI("Juego descargado limpiamente de FBNeo.");
   }
   g_input_bitmask.store(0);
   // NOTA: NO llamamos a core_retro_deinit() ni dlclose() porque libfbneo.so
   // permanece en el espacio de memoria de Android y su re-inicialización
   // causaría corrupción de heap en allocators como Scudo.
   // El core permanece listo para cargar el siguiente juego mediante retro_load_game.
}


}
