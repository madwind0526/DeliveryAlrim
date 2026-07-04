package com.checkshipping.check_shipping

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.util.Calendar
import java.util.UUID

data class KakaoParcelCapture(
    val courierCode: String,
    val trackingNumber: String,
    val status: String,
    val sender: String?,
    val capturedAtMillis: Long,
)

class LocalParcelSqliteStore(private val context: Context) {
    fun upsert(capture: KakaoParcelCapture) {
        val dbFile = File(context.applicationInfo.dataDir, DB_RELATIVE_PATH)
        dbFile.parentFile?.mkdirs()

        val db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
        db.beginTransaction()
        try {
            ensureSchema(db)
            upsertInTransaction(db, capture)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
            db.close()
        }
    }

    private fun ensureSchema(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS "parcel_rows" (
              "id" TEXT NOT NULL,
              "courier_code" TEXT NOT NULL,
              "tracking_number" TEXT NOT NULL,
              "status" TEXT NOT NULL,
              "product_name" TEXT NULL,
              "mall_name" TEXT NULL,
              "source_channels" TEXT NOT NULL DEFAULT '',
              "expected_arrival_date" INTEGER NULL,
              "delivered_at" INTEGER NULL,
              "registered_at" INTEGER NOT NULL,
              PRIMARY KEY ("id"),
              UNIQUE ("courier_code", "tracking_number")
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS "tracking_event_rows" (
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "parcel_id" TEXT NOT NULL,
              "event_time" INTEGER NOT NULL,
              "status_code" TEXT NOT NULL,
              "location" TEXT NULL,
              "description" TEXT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS "local_profile_rows" (
              "id" INTEGER NOT NULL,
              "display_name" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              PRIMARY KEY ("id")
            )
            """.trimIndent(),
        )
        db.execSQL("PRAGMA user_version = 2")
    }

    private fun upsertInTransaction(db: SQLiteDatabase, capture: KakaoParcelCapture) {
        val capturedAtSeconds = capture.capturedAtMillis / 1000L
        db.rawQuery(
            """
            SELECT id, status, product_name, mall_name, source_channels,
                   expected_arrival_date, delivered_at, registered_at
            FROM parcel_rows
            WHERE courier_code = ? AND tracking_number = ?
            """.trimIndent(),
            arrayOf(capture.courierCode, capture.trackingNumber),
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getString(0)
                val previousStatus = cursor.getString(1)
                val nextStatus = chooseForwardStatus(previousStatus, capture.status)
                val values = ContentValues().apply {
                    put("status", nextStatus)
                    put("product_name", cursor.getNullableString(2))
                    put("mall_name", cursor.getNullableString(3) ?: capture.sender)
                    put("source_channels", mergeSourceChannels(cursor.getNullableString(4)))
                    put("expected_arrival_date", expectedArrival(nextStatus, capturedAtSeconds))
                    put("delivered_at", deliveredAt(nextStatus, capturedAtSeconds, cursor.getNullableLong(6)))
                    put("registered_at", cursor.getLong(7))
                }
                db.update(
                    "parcel_rows",
                    values,
                    "courier_code = ? AND tracking_number = ?",
                    arrayOf(capture.courierCode, capture.trackingNumber),
                )
                if (nextStatus != previousStatus) {
                    insertEvent(db, id, nextStatus, capturedAtSeconds)
                }
            } else {
                val id = UUID.randomUUID().toString()
                val values = ContentValues().apply {
                    put("id", id)
                    put("courier_code", capture.courierCode)
                    put("tracking_number", capture.trackingNumber)
                    put("status", capture.status)
                    putNull("product_name")
                    put("mall_name", capture.sender)
                    put("source_channels", SOURCE_KAKAO)
                    put("expected_arrival_date", expectedArrival(capture.status, capturedAtSeconds))
                    put("delivered_at", deliveredAt(capture.status, capturedAtSeconds, null))
                    put("registered_at", capturedAtSeconds)
                }
                db.insertWithOnConflict("parcel_rows", null, values, SQLiteDatabase.CONFLICT_REPLACE)
                insertEvent(db, id, capture.status, capturedAtSeconds)
            }
        }
    }

    private fun insertEvent(
        db: SQLiteDatabase,
        parcelId: String,
        status: String,
        eventTime: Long,
    ) {
        val event = ContentValues().apply {
            put("parcel_id", parcelId)
            put("event_time", eventTime)
            put("status_code", status)
            putNull("location")
            put("description", "카카오톡 알림톡")
        }
        db.insert("tracking_event_rows", null, event)
    }

    private fun chooseForwardStatus(previous: String, next: String): String {
        return if (statusRank(next) > statusRank(previous)) next else previous
    }

    private fun statusRank(status: String): Int {
        return STATUS_ORDER.indexOf(status).takeIf { it >= 0 } ?: 0
    }

    private fun mergeSourceChannels(existing: String?): String {
        return (existing.orEmpty().split(",") + SOURCE_KAKAO)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
            .joinToString(",")
    }

    private fun expectedArrival(status: String, capturedAtSeconds: Long): Long? {
        if (status != "out_for_delivery") return null
        val calendar = Calendar.getInstance().apply {
            timeInMillis = capturedAtSeconds * 1000L
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return calendar.timeInMillis / 1000L
    }

    private fun deliveredAt(status: String, capturedAtSeconds: Long, existing: Long?): Long? {
        return if (status == "delivered") capturedAtSeconds else existing
    }

    private fun android.database.Cursor.getNullableString(index: Int): String? {
        return if (isNull(index)) null else getString(index)
    }

    private fun android.database.Cursor.getNullableLong(index: Int): Long? {
        return if (isNull(index)) null else getLong(index)
    }

    companion object {
        private const val DB_RELATIVE_PATH = "app_flutter/check_shipping.sqlite"
        private const val SOURCE_KAKAO = "kakao"
        private val STATUS_ORDER = listOf(
            "registered",
            "preparing",
            "picked_up",
            "in_transit",
            "out_for_delivery",
            "delivered",
            "expired",
            "invalid",
        )
    }
}
