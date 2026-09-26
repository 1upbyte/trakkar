package com.oneupbyte.trakkar.bridge

import android.database.sqlite.SQLiteDatabase
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SdkConfigResetBridgeTest {
    @Test
    fun refusesResetWhileQueuedPositionsExistAndPreservesBothTables() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val databaseFile = File(context.cacheDir, "sdk-reset-test.db")
        databaseFile.delete()
        SQLiteDatabase.openOrCreateDatabase(databaseFile, null).use { database ->
            database.execSQL("CREATE TABLE Config (id INTEGER PRIMARY KEY, json TEXT NOT NULL)")
            database.execSQL("CREATE TABLE Position (id INTEGER PRIMARY KEY, latitude REAL)")
            database.execSQL("INSERT INTO Config (id, json) VALUES (1, 'secret config')")
            database.execSQL("INSERT INTO Position (id, latitude) VALUES (1, 35.0), (2, 36.0)")

            try {
                SdkConfigResetBridge(context).clearConfiguration(database)
                throw AssertionError("Reset should fail while positions are queued")
            } catch (expected: IllegalStateException) {
                assertEquals("Pending positions must sync before reset", expected.message)
            }

            assertEquals(1L, scalar(database, "SELECT COUNT(*) FROM Config"))
            assertEquals(2L, scalar(database, "SELECT COUNT(*) FROM Position"))
        }
        databaseFile.delete()
    }

    @Test
    fun clearsConfigWhenQueueIsEmpty() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val databaseFile = File(context.cacheDir, "sdk-reset-empty-test.db")
        databaseFile.delete()
        SQLiteDatabase.openOrCreateDatabase(databaseFile, null).use { database ->
            database.execSQL("CREATE TABLE Config (id INTEGER PRIMARY KEY, json TEXT NOT NULL)")
            database.execSQL("CREATE TABLE Position (id INTEGER PRIMARY KEY, latitude REAL)")
            database.execSQL("INSERT INTO Config (id, json) VALUES (1, 'config')")

            SdkConfigResetBridge(context).clearConfiguration(database)

            assertEquals(0L, scalar(database, "SELECT COUNT(*) FROM Config"))
            assertEquals(0L, scalar(database, "SELECT COUNT(*) FROM Position"))
        }
        databaseFile.delete()
    }

    private fun scalar(database: SQLiteDatabase, sql: String): Long =
        database.rawQuery(sql, null).use { cursor ->
            check(cursor.moveToFirst())
            cursor.getLong(0)
        }
}
