# Reglas de ProGuard/R8 para moai3

# Preservar el paquete de contrato v1 de plugins (.dex) intacto
# Evita que R8 borre u ofusque interfaces/clases requeridas por los plugins
-keep class com.infomak.moai.contract.** { *; }
-keep interface com.infomak.moai.contract.** { *; }
-keepclassmembers class com.infomak.moai.contract.** { *; }

# Titan Ranger: libranger-jni.so busca estas clases, métodos y campos por
# nombre (JNI) y Gson serializa los beans por reflexión. Si R8 las renombra o
# las borra, reproducir una película cierra la app (ClassNotFoundException).
-keep class com.titan.ranger.** { *; }
