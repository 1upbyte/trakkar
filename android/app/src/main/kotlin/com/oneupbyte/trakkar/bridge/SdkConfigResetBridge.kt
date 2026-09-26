package com.oneupbyte.trakkar.bridge

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/** Clears the SDK connection row while leaving its buffered Position rows intact. */
class SdkConfigResetBridge(private val context: Context) {
    fun clearConfiguration() {
        val databaseFile = context.getDatabasePath(DATABASE_NAME)
        if (!databaseFile.exists()) return
        clearConfiguration(databaseFile)
    }

    internal fun clearConfiguration(databaseFile: File) {
        SQLiteDatabase.openDatabase(
            databaseFile.absolutePath,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        ).use { database ->
            clearConfiguration(database)
        }
    }

    internal fun clearConfiguration(database: SQLiteDatabase) {
        val tables = database.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (?, ?)",
            arrayOf(CONFIG_TABLE, POSITION_TABLE),
        ).use { cursor ->
            buildSet {
                while (cursor.moveToNext()) add(cursor.getString(0))
            }
        }
        check(tables.containsAll(setOf(CONFIG_TABLE, POSITION_TABLE))) {
            "Tracking SDK database schema is unavailable"
        }
        database.beginTransaction()
        try {
            val queuedBefore = positionCount(database)
            check(queuedBefore == 0L) { "Pending positions must sync before reset" }
            database.delete(CONFIG_TABLE, "id = ?", arrayOf("1"))
            check(positionCount(database) == queuedBefore) {
                "Tracking queue changed while clearing SDK configuration"
            }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
    }

    private fun positionCount(database: SQLiteDatabase): Long =
        database.rawQuery("SELECT COUNT(*) FROM Position", null).use { cursor ->
            check(cursor.moveToFirst())
            cursor.getLong(0)
        }

    companion object {
        private const val DATABASE_NAME = "tracker.db"
        private const val CONFIG_TABLE = "Config"
        private const val POSITION_TABLE = "Position"
    }
}
