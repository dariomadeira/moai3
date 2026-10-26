package com.infomak.moai

import android.net.Uri
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener

/**
 * Elige el idioma del audio en películas de Titan Ranger.
 *
 * Los tramos TS traen varios audios del mismo tipo (p. ej. AAC en los PID
 * 257 "spa", 258 "spa", 259 "eng") y ExoPlayer, en HLS, se queda sólo con el
 * de PID más bajo. Este DataSource intercambia, paquete por paquete, el PID
 * del audio en [preferredLanguage] con el del primero (y sus etiquetas de
 * idioma en la PMT, recalculando el CRC), así ExoPlayer toma el pedido.
 *
 * Sólo toca TS (sync 0x47); la lista .m3u8 u otra cosa pasa igual. Si el
 * idioma no está o ya es el primero, no cambia nada.
 */
@UnstableApi
class TsAudioSwapDataSource(
    private val upstream: DataSource,
    preferredLanguage: String,
) : DataSource {

    private val preferred = Util.normalizeLanguageCode(preferredLanguage)

    // Paquetes listos para entregar: [out, outStart, outEnd). Lo que sobra de
    // un paquete incompleto queda en [carry] hasta la próxima lectura.
    private val out = ByteArray(PACKET * 64)
    private var outStart = 0
    private var outEnd = 0
    private val carry = ByteArray(PACKET)
    private var carryLen = 0
    private var upstreamEnded = false

    /** null: todavía no se sabe; false: no es TS, se entrega tal cual. */
    private var isTs: Boolean? = null
    private var pmtPid = -1

    /** PID original → PID con el que se entrega (los dos del intercambio). */
    private var swap: Map<Int, Int> = emptyMap()

    override fun addTransferListener(transferListener: TransferListener) {
        upstream.addTransferListener(transferListener)
    }

    override fun open(dataSpec: DataSpec): Long {
        outStart = 0
        outEnd = 0
        carryLen = 0
        upstreamEnded = false
        isTs = null
        pmtPid = -1
        swap = emptyMap()
        return upstream.open(dataSpec)
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        if (outStart == outEnd && !fill()) return C.RESULT_END_OF_INPUT
        val n = minOf(length, outEnd - outStart)
        System.arraycopy(out, outStart, buffer, offset, n)
        outStart += n
        return n
    }

    /** Llena [out] con paquetes completos ya procesados. false: no hay más. */
    private fun fill(): Boolean {
        outStart = 0
        outEnd = 0
        System.arraycopy(carry, 0, out, 0, carryLen)
        var filled = carryLen
        carryLen = 0
        while (!upstreamEnded && filled < PACKET) {
            val r = upstream.read(out, filled, out.size - filled)
            if (r == C.RESULT_END_OF_INPUT) upstreamEnded = true else filled += r
        }
        if (filled == 0) return false
        if (isTs == null) isTs = out[0] == SYNC
        if (isTs == false || upstreamEnded) {
            // No TS, o lo último: lo completo se procesa y el resto va igual.
            val whole = if (isTs == true) filled - filled % PACKET else 0
            processPackets(whole)
            outEnd = filled
            return true
        }
        val whole = filled - filled % PACKET
        carryLen = filled - whole
        System.arraycopy(out, whole, carry, 0, carryLen)
        processPackets(whole)
        outEnd = whole
        return true
    }

    private fun processPackets(length: Int) {
        var p = 0
        while (p + PACKET <= length) {
            if (out[p] != SYNC) {
                // Se perdió la alineación: no tocar nada más de este tramo.
                isTs = false
                return
            }
            val pid = ((out[p + 1].toInt() and 0x1f) shl 8) or (out[p + 2].toInt() and 0xff)
            val pusi = out[p + 1].toInt() and 0x40 != 0
            when {
                pid == 0 && pusi -> readPat(p)
                pid == pmtPid && pusi -> rewritePmt(p)
            }
            swap[pid]?.let { newPid ->
                out[p + 1] = ((out[p + 1].toInt() and 0xe0) or (newPid shr 8)).toByte()
                out[p + 2] = (newPid and 0xff).toByte()
            }
            p += PACKET
        }
    }

    /** Desde dónde empieza la sección (tras el pointer_field), o -1. */
    private fun sectionStart(p: Int): Int {
        val afc = (out[p + 3].toInt() shr 4) and 3
        var i = p + 4
        if (afc and 2 != 0) i += 1 + (out[i].toInt() and 0xff)
        if (afc and 1 == 0 || i >= p + PACKET) return -1
        i += 1 + (out[i].toInt() and 0xff)
        return if (i < p + PACKET) i else -1
    }

    private fun readPat(p: Int) {
        val s = sectionStart(p)
        if (s < 0) return
        val len = ((out[s + 1].toInt() and 0x0f) shl 8) or (out[s + 2].toInt() and 0xff)
        var k = s + 8
        val end = minOf(s + 3 + len - 4, p + PACKET - 4)
        while (k + 4 <= end) {
            val program = ((out[k].toInt() and 0xff) shl 8) or (out[k + 1].toInt() and 0xff)
            if (program != 0) {
                pmtPid = ((out[k + 2].toInt() and 0x1f) shl 8) or (out[k + 3].toInt() and 0xff)
                return
            }
            k += 4
        }
    }

    private class Es(val type: Int, val pid: Int, val langAt: Int, val lang: String?)

    /** Lee la PMT, decide el intercambio y cambia las etiquetas de idioma. */
    private fun rewritePmt(p: Int) {
        val s = sectionStart(p)
        if (s < 0) return
        val len = ((out[s + 1].toInt() and 0x0f) shl 8) or (out[s + 2].toInt() and 0xff)
        val crcAt = s + 3 + len - 4
        if (crcAt + 4 > p + PACKET) return // PMT en más de un paquete: no se toca
        val infoLen = ((out[s + 10].toInt() and 0x0f) shl 8) or (out[s + 11].toInt() and 0xff)
        var k = s + 12 + infoLen
        val streams = mutableListOf<Es>()
        while (k + 5 <= crcAt) {
            val type = out[k].toInt() and 0xff
            val pid = ((out[k + 1].toInt() and 0x1f) shl 8) or (out[k + 2].toInt() and 0xff)
            val esLen = ((out[k + 3].toInt() and 0x0f) shl 8) or (out[k + 4].toInt() and 0xff)
            var d = k + 5
            var langAt = -1
            while (d + 2 <= k + 5 + esLen) {
                val tag = out[d].toInt() and 0xff
                val dLen = out[d + 1].toInt() and 0xff
                if (tag == ISO_639_TAG && dLen >= 3) langAt = d + 2
                d += 2 + dLen
            }
            val lang = if (langAt >= 0) String(out, langAt, 3, Charsets.ISO_8859_1) else null
            streams.add(Es(type, pid, langAt, lang))
            k += 5 + esLen
        }

        if (swap.isEmpty()) {
            val audios = streams.filter { it.type in AUDIO_TYPES }
            val target = audios.firstOrNull {
                it.lang != null && Util.normalizeLanguageCode(it.lang) == preferred
            } ?: return
            val first = audios.filter { it.type == target.type }.minByOrNull { it.pid } ?: return
            // El intercambio sólo cambia el byte bajo del PID: los altos deben coincidir.
            if (first.pid == target.pid || first.pid shr 8 != target.pid shr 8) return
            swap = mapOf(target.pid to first.pid, first.pid to target.pid)
            Log.i(PlayerEngine.TAG, "audio: ${target.lang} (pid ${target.pid}) pasa al " +
                "pid ${first.pid} en lugar de ${first.lang}")
        }

        // Las etiquetas viajan con su audio: la del nuevo primero dice el idioma pedido.
        val a = streams.firstOrNull { it.pid in swap && it.langAt >= 0 } ?: return
        val b = streams.firstOrNull { it.pid == swap[a.pid] && it.langAt >= 0 } ?: return
        for (i in 0 until 3) {
            val t = out[a.langAt + i]
            out[a.langAt + i] = out[b.langAt + i]
            out[b.langAt + i] = t
        }
        val crc = crc32Mpeg(out, s, crcAt - s)
        out[crcAt] = (crc ushr 24).toByte()
        out[crcAt + 1] = (crc ushr 16).toByte()
        out[crcAt + 2] = (crc ushr 8).toByte()
        out[crcAt + 3] = crc.toByte()
    }

    override fun getUri(): Uri? = upstream.uri

    override fun getResponseHeaders(): Map<String, List<String>> = upstream.responseHeaders

    override fun close() {
        upstream.close()
    }

    companion object {
        private const val PACKET = 188
        private const val SYNC: Byte = 0x47
        private const val ISO_639_TAG = 0x0a

        /** MPEG-1/2 audio, AAC (ADTS/LATM), AC-3 y E-AC-3. */
        private val AUDIO_TYPES = setOf(0x03, 0x04, 0x0f, 0x11, 0x81, 0x87)

        /** CRC-32/MPEG-2 de las secciones PSI. */
        fun crc32Mpeg(data: ByteArray, start: Int, length: Int): Int {
            var crc = -1
            for (i in start until start + length) {
                crc = crc xor ((data[i].toInt() and 0xff) shl 24)
                repeat(8) {
                    crc = if (crc < 0) (crc shl 1) xor 0x04C11DB7 else crc shl 1
                }
            }
            return crc
        }
    }
}
