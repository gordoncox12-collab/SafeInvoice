package app.safeinvoice.di

import android.content.Context
import androidx.room.Room
import app.safeinvoice.data.db.AppDatabase
import app.safeinvoice.data.entity.AppSettingsEntity
import app.safeinvoice.data.excel.ExcelService
import app.safeinvoice.data.files.LocalStorage
import app.safeinvoice.data.pdf.InvoicePdfGenerator
import app.safeinvoice.data.repo.InvoiceRepository
import app.safeinvoice.data.share.ShareHelper
import kotlinx.coroutines.runBlocking

class AppContainer(context: Context) {
    val db: AppDatabase = Room.databaseBuilder(
        context,
        AppDatabase::class.java,
        "safeinvoice.db",
    ).fallbackToDestructiveMigration().build()

    val storage = LocalStorage(context)
    val excel = ExcelService(context)
    val pdf = InvoicePdfGenerator(context, storage)
    val share = ShareHelper(context)
    val repo = InvoiceRepository(context, db, storage, excel, pdf)

    init {
        runBlocking {
            if (db.settingsDao().get() == null) {
                db.settingsDao().upsert(AppSettingsEntity(activeBusinessId = null))
            }
            repo.markOverdue()
        }
    }
}
