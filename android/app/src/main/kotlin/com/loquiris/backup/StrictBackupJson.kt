package com.loquiris.backup

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

internal class StrictBackupJson private constructor(
    private val source: String,
) {
    private var offset = 0

    fun parse(): Any? {
        val value = parseValue(0)
        skipWhitespace()
        if (offset != source.length) invalid()
        return value
    }

    private fun parseValue(depth: Int): Any? {
        if (depth > MAX_DEPTH) invalid()
        skipWhitespace()
        if (offset >= source.length) invalid()
        return when (source[offset]) {
            '{' -> parseObject(depth + 1)
            '[' -> parseArray(depth + 1)
            '"' -> parseString()
            't' -> literal("true", true)
            'f' -> literal("false", false)
            'n' -> literal("null", null)
            '-', in '0'..'9' -> parseInteger()
            else -> invalid()
        }
    }

    private fun parseObject(depth: Int): Map<String, Any?> {
        offset += 1
        skipWhitespace()
        val result = linkedMapOf<String, Any?>()
        if (takeIf('}')) return result
        while (true) {
            skipWhitespace()
            if (offset >= source.length || source[offset] != '"') invalid()
            val key = parseString()
            if (result.containsKey(key)) invalid()
            skipWhitespace()
            requireCharacter(':')
            result[key] = parseValue(depth)
            skipWhitespace()
            if (takeIf('}')) return result
            requireCharacter(',')
        }
    }

    private fun parseArray(depth: Int): List<Any?> {
        offset += 1
        skipWhitespace()
        val result = mutableListOf<Any?>()
        if (takeIf(']')) return result
        while (true) {
            if (result.size >= MAX_ITEMS) invalid()
            result += parseValue(depth)
            skipWhitespace()
            if (takeIf(']')) return result
            requireCharacter(',')
        }
    }

    private fun parseString(): String {
        requireCharacter('"')
        val result = StringBuilder()
        while (offset < source.length) {
            val character = source[offset++]
            when {
                character == '"' -> return result.toString()
                character == '\\' -> {
                    if (offset >= source.length) invalid()
                    when (val escaped = source[offset++]) {
                        '"', '\\', '/' -> result.append(escaped)
                        'b' -> result.append('\b')
                        'f' -> result.append('\u000c')
                        'n' -> result.append('\n')
                        'r' -> result.append('\r')
                        't' -> result.append('\t')
                        'u' -> result.append(parseUnicodeEscape())
                        else -> invalid()
                    }
                }
                character.code < 0x20 -> invalid()
                else -> result.append(character)
            }
            if (result.length > MAX_STRING_CHARACTERS) invalid()
        }
        return invalid()
    }

    private fun parseUnicodeEscape(): Char {
        if (source.length - offset < 4) invalid()
        val value = source.substring(offset, offset + 4).toIntOrNull(16) ?: invalid()
        offset += 4
        return value.toChar()
    }

    private fun parseInteger(): Long {
        val start = offset
        if (source[offset] == '-') offset += 1
        if (offset >= source.length) invalid()
        if (source[offset] == '0') {
            offset += 1
            if (offset < source.length && source[offset].isDigit()) invalid()
        } else {
            if (source[offset] !in '1'..'9') invalid()
            while (offset < source.length && source[offset].isDigit()) offset += 1
        }
        return source.substring(start, offset).toLongOrNull() ?: invalid()
    }

    private fun <T> literal(
        text: String,
        value: T,
    ): T {
        if (!source.startsWith(text, offset)) invalid()
        offset += text.length
        return value
    }

    private fun requireCharacter(expected: Char) {
        skipWhitespace()
        if (offset >= source.length || source[offset] != expected) invalid()
        offset += 1
    }

    private fun takeIf(expected: Char): Boolean {
        if (offset < source.length && source[offset] == expected) {
            offset += 1
            return true
        }
        return false
    }

    private fun skipWhitespace() {
        while (offset < source.length && source[offset] in JSON_WHITESPACE) offset += 1
    }

    private fun invalid(): Nothing = throw IllegalArgumentException("invalid backup JSON")

    companion object {
        fun parse(bytes: ByteArray): Any? {
            val text =
                StandardCharsets.UTF_8
                    .newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString()
            return StrictBackupJson(text).parse()
        }

        private const val MAX_DEPTH = 32
        private const val MAX_ITEMS = 20_000
        private const val MAX_STRING_CHARACTERS = 1024 * 1024
        private val JSON_WHITESPACE = setOf(' ', '\t', '\r', '\n')
    }
}
