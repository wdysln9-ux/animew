package com.spyou.watch_app

import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.EOFException
import java.io.File
import java.io.FileInputStream
import java.io.FilterInputStream
import java.io.InputStream
import java.io.RandomAccessFile

/**
 * Applies the BSDIFF40 format used by the GitHub release workflow.
 *
 * All three compressed streams and the base APK are processed in bounded
 * chunks so rebuilding an APK does not require keeping the whole APK in RAM.
 */
object ApkDeltaPatcher {
    private const val HEADER_SIZE = 32
    private const val BUFFER_SIZE = 64 * 1024
    private const val MAX_OUTPUT_SIZE = 300L * 1024L * 1024L

    fun apply(base: File, patch: File, output: File, expectedSize: Long): File {
        require(base.isFile && patch.isFile) { "Base APK or patch is missing" }
        require(expectedSize in 1..MAX_OUTPUT_SIZE) { "Invalid target APK size" }

        RandomAccessFile(patch, "r").use { header ->
            require(header.length() >= HEADER_SIZE) { "Patch header is truncated" }
            val magic = ByteArray(8)
            header.readFully(magic)
            require(String(magic, Charsets.US_ASCII) == "BSDIFF40") { "Unsupported patch format" }

            val controlLength = readOffset(header)
            val diffLength = readOffset(header)
            val newSize = readOffset(header)
            require(controlLength >= 0 && diffLength >= 0 && newSize == expectedSize) {
                "Patch metadata does not match"
            }
            val extraLength = header.length() - HEADER_SIZE - controlLength - diffLength
            require(extraLength > 0 && HEADER_SIZE + controlLength + diffLength <= header.length()) {
                "Patch streams are truncated"
            }

            val control = bzipStream(patch, HEADER_SIZE, controlLength)
            val diff = bzipStream(patch, HEADER_SIZE + controlLength, diffLength)
            val extra = bzipStream(
                patch,
                HEADER_SIZE + controlLength + diffLength,
                extraLength,
            )

            val old = RandomAccessFile(base, "r")
            try {
                output.parentFile?.mkdirs()
                BufferedOutputStream(output.outputStream(), BUFFER_SIZE).use { out ->
                    var oldPosition = 0L
                    var newPosition = 0L
                    val controlBytes = ByteArray(24)
                    val diffBytes = ByteArray(BUFFER_SIZE)
                    val oldBytes = ByteArray(BUFFER_SIZE)
                    val extraBytes = ByteArray(BUFFER_SIZE)

                    while (newPosition < newSize) {
                        readFully(control, controlBytes, 24)
                        val addLength = decodeOffset(controlBytes, 0)
                        val copyLength = decodeOffset(controlBytes, 8)
                        val seekAdjustment = decodeOffset(controlBytes, 16)
                        require(addLength >= 0 && copyLength >= 0) { "Invalid patch control tuple" }
                        require(addLength + copyLength <= newSize - newPosition) {
                            "Patch output exceeds declared size"
                        }

                        var remaining = addLength
                        while (remaining > 0) {
                            val count = minOf(BUFFER_SIZE.toLong(), remaining).toInt()
                            readFully(diff, diffBytes, count)
                            oldBytes.fill(0, 0, count)

                            val sourceStart = maxOf(0L, oldPosition)
                            val sourceEnd = minOf(old.length(), oldPosition + count)
                            if (sourceEnd > sourceStart) {
                                val destinationOffset = (sourceStart - oldPosition).toInt()
                                val available = (sourceEnd - sourceStart).toInt()
                                old.seek(sourceStart)
                                old.readFully(oldBytes, destinationOffset, available)
                            }
                            for (i in 0 until count) {
                                diffBytes[i] = ((diffBytes[i].toInt() and 0xff) +
                                    (oldBytes[i].toInt() and 0xff)).toByte()
                            }
                            out.write(diffBytes, 0, count)
                            oldPosition += count
                            newPosition += count
                            remaining -= count
                        }

                        remaining = copyLength
                        while (remaining > 0) {
                            val count = minOf(BUFFER_SIZE.toLong(), remaining).toInt()
                            readFully(extra, extraBytes, count)
                            out.write(extraBytes, 0, count)
                            newPosition += count
                            remaining -= count
                        }
                        oldPosition += seekAdjustment
                    }
                    out.flush()
                }
            } catch (error: Exception) {
                output.delete()
                throw error
            } finally {
                old.close()
                control.close()
                diff.close()
                extra.close()
            }
        }
        require(output.isFile && output.length() == expectedSize) {
            output.delete()
            "Reconstructed APK has an unexpected size"
        }
        return output
    }

    private fun bzipStream(file: File, offset: Long, length: Long): InputStream {
        require(length > 0) { "Empty compressed patch stream" }
        val raw = FileInputStream(file)
        var skipped = 0L
        while (skipped < offset) {
            val amount = raw.skip(offset - skipped)
            if (amount <= 0) {
                raw.close()
                throw EOFException("Could not seek to patch stream")
            }
            skipped += amount
        }
        return BZip2CompressorInputStream(
            LimitedInputStream(BufferedInputStream(raw), length),
            false,
        )
    }

    private fun readOffset(file: RandomAccessFile): Long {
        val bytes = ByteArray(8)
        file.readFully(bytes)
        return decodeOffset(bytes, 0)
    }

    /** BSDIFF uses little-endian sign-magnitude 64-bit integers. */
    private fun decodeOffset(bytes: ByteArray, offset: Int): Long {
        var value = 0L
        for (i in 0..7) {
            value = value or ((bytes[offset + i].toLong() and 0xffL) shl (8 * i))
        }
        val negative = (value and Long.MIN_VALUE) != 0L
        val magnitude = value and Long.MAX_VALUE
        return if (negative) -magnitude else magnitude
    }

    private fun readFully(input: InputStream, target: ByteArray, length: Int) {
        var offset = 0
        while (offset < length) {
            val count = input.read(target, offset, length - offset)
            if (count < 0) throw EOFException("Patch stream ended early")
            offset += count
        }
    }

    private class LimitedInputStream(input: InputStream, length: Long) : FilterInputStream(input) {
        private var remaining = length

        override fun read(): Int {
            if (remaining <= 0) return -1
            val value = super.read()
            if (value >= 0) remaining--
            return value
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            if (remaining <= 0) return -1
            val count = super.read(buffer, offset, minOf(length.toLong(), remaining).toInt())
            if (count > 0) remaining -= count
            return count
        }

        override fun skip(count: Long): Long {
            val skipped = super.skip(minOf(count, remaining))
            remaining -= skipped
            return skipped
        }
    }
}
