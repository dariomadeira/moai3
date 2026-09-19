# Reglas de ProGuard/R8 para moai3

# Preservar el paquete de contrato v1 de plugins (.dex) intacto
# Evita que R8 borre u ofusque interfaces/clases requeridas por los plugins
-keep class com.infomak.moai.contract.** { *; }
-keep interface com.infomak.moai.contract.** { *; }
-keepclassmembers class com.infomak.moai.contract.** { *; }
