package app.safeinvoice.data.db

import androidx.room.Database
import androidx.room.RoomDatabase
import app.safeinvoice.data.entity.AppSettingsEntity
import app.safeinvoice.data.entity.BusinessEntity
import app.safeinvoice.data.entity.CustomerEntity
import app.safeinvoice.data.entity.FolderFileEntity
import app.safeinvoice.data.entity.InvoiceEntity
import app.safeinvoice.data.entity.InvoiceImageEntity
import app.safeinvoice.data.entity.InvoiceLineItemEntity
import app.safeinvoice.data.entity.InvoiceTemplateEntity
import app.safeinvoice.data.entity.NoteEntity
import app.safeinvoice.data.entity.TransactionEntity

@Database(
    entities = [
        BusinessEntity::class,
        CustomerEntity::class,
        InvoiceEntity::class,
        InvoiceLineItemEntity::class,
        InvoiceImageEntity::class,
        TransactionEntity::class,
        NoteEntity::class,
        FolderFileEntity::class,
        InvoiceTemplateEntity::class,
        AppSettingsEntity::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun businessDao(): BusinessDao
    abstract fun customerDao(): CustomerDao
    abstract fun invoiceDao(): InvoiceDao
    abstract fun transactionDao(): TransactionDao
    abstract fun noteDao(): NoteDao
    abstract fun folderFileDao(): FolderFileDao
    abstract fun templateDao(): TemplateDao
    abstract fun settingsDao(): SettingsDao
}
