package com.loquiris.remote

import android.content.ContentValues
import androidx.sqlite.SQLiteConnection
import androidx.sqlite.SQLiteStatement
import androidx.sqlite.driver.bundled.BundledSQLiteDriver

/** Uses a modern SQLite runtime: Android 10's system SQLite cannot read STRICT tables. */
class RemoteSqlite(path: String): AutoCloseable {
    private val connection: SQLiteConnection = BundledSQLiteDriver().open(path)
    private var successful=false
    init { execSQL("PRAGMA busy_timeout=5000");execSQL("PRAGMA foreign_keys=ON");execSQL("PRAGMA synchronous=FULL") }
    fun execSQL(sql: String) { connection.prepare(sql).use { it.step() } }
    fun rawQuery(sql: String, arguments: Array<String>?): RemoteCursor {
        val statement=connection.prepare(sql)
        arguments?.forEachIndexed { i,value -> statement.bindText(i+1,value) }
        return RemoteCursor(statement)
    }
    private fun execute(sql: String, values: List<Any?>) {
        connection.prepare(sql).use { statement ->
            values.forEachIndexed { index,value -> when(value) {
                null -> statement.bindNull(index+1)
                is Int -> statement.bindLong(index+1,value.toLong())
                is Long -> statement.bindLong(index+1,value)
                else -> statement.bindText(index+1,value.toString())
            } }
            statement.step()
        }
    }
    fun update(table: String, content: ContentValues, where: String, arguments: Array<String>) {
        val entries=content.keySet().sorted().map { key -> key to content.get(key) }
        execute("UPDATE $table SET ${entries.joinToString(",") { "${it.first}=?" }} WHERE $where",
            entries.map { it.second }+arguments.toList())
    }
    fun insertWithOnConflict(table: String, unused: String?, content: ContentValues, conflict: Int) {
        val entries=content.keySet().sorted().map { key -> key to content.get(key) }
        execute("INSERT OR IGNORE INTO $table (${entries.joinToString(",") { it.first }}) VALUES (${entries.joinToString(",") { "?" }})",entries.map { it.second })
    }
    fun beginTransaction() { successful=false;execSQL("BEGIN IMMEDIATE") }
    fun setTransactionSuccessful() { successful=true }
    fun endTransaction() { execSQL(if(successful) "COMMIT" else "ROLLBACK");successful=false }
    override fun close() { connection.close() }
}

class RemoteCursor(private val statement: SQLiteStatement): AutoCloseable {
    val columnNames: Array<String> get() = Array(statement.getColumnCount()) { statement.getColumnName(it) }
    fun getColumnIndexOrThrow(name: String): Int = columnNames.indexOf(name).also { require(it>=0) }
    fun moveToNext(): Boolean = statement.step()
    fun moveToFirst(): Boolean = statement.step()
    fun isNull(index: Int): Boolean = statement.isNull(index)
    fun getString(index: Int): String = statement.getText(index)
    fun getInt(index: Int): Int = statement.getLong(index).toInt()
    override fun close() { statement.close() }
}
