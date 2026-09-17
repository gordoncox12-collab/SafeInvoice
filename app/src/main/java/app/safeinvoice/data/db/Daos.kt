package app.safeinvoice.data.db

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import app.safeinvoice.data.entity.AppSettingsEntity
import app.safeinvoice.data.entity.BusinessEntity
import app.safeinvoice.data.entity.CustomerEntity
import app.safeinvoice.data.entity.FolderFileEntity
import app.safeinvoice.data.entity.InvoiceEntity
import app.safeinvoice.data.entity.InvoiceImageEntity
import app.safeinvoice.data.entity.InvoiceLineItemEntity
import app.safeinvoice.data.entity.InvoiceTemplateEntity
import app.safeinvoice.data.entity.InvoiceWithDetails
import app.safeinvoice.data.entity.NoteEntity
import app.safeinvoice.data.entity.TransactionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface BusinessDao {
    @Query("SELECT * FROM businesses ORDER BY name")
    fun observeAll(): Flow<List<BusinessEntity>>

    @Query("SELECT * FROM businesses ORDER BY name")
    suspend fun getAll(): List<BusinessEntity>

    @Query("SELECT * FROM businesses WHERE id = :id")
    suspend fun get(id: String): BusinessEntity?

    @Query("SELECT COUNT(*) FROM businesses")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: BusinessEntity)

    @Delete
    suspend fun delete(entity: BusinessEntity)
}

@Dao
interface CustomerDao {
    @Query("SELECT * FROM customers WHERE businessId = :businessId ORDER BY name")
    fun observeForBusiness(businessId: String): Flow<List<CustomerEntity>>

    @Query("SELECT * FROM customers WHERE businessId = :businessId ORDER BY name")
    suspend fun forBusiness(businessId: String): List<CustomerEntity>

    @Query("SELECT * FROM customers WHERE id = :id")
    suspend fun get(id: String): CustomerEntity?

    @Query("SELECT * FROM customers WHERE id = :id")
    fun observe(id: String): Flow<CustomerEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: CustomerEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<CustomerEntity>)

    @Delete
    suspend fun delete(entity: CustomerEntity)
}

@Dao
interface InvoiceDao {
    @Query("SELECT * FROM invoices WHERE businessId = :businessId ORDER BY issueDate DESC")
    fun observeForBusiness(businessId: String): Flow<List<InvoiceEntity>>

    @Query("SELECT * FROM invoices WHERE customerId = :customerId ORDER BY issueDate DESC")
    fun observeForCustomer(customerId: String): Flow<List<InvoiceEntity>>

    @Query("SELECT * FROM invoices WHERE id = :id")
    suspend fun get(id: String): InvoiceEntity?

    @Transaction
    @Query("SELECT * FROM invoices WHERE id = :id")
    suspend fun getWithDetails(id: String): InvoiceWithDetails?

    @Query("SELECT * FROM invoices WHERE businessId = :businessId")
    suspend fun forBusiness(businessId: String): List<InvoiceEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: InvoiceEntity)

    @Query("UPDATE invoices SET status = :status, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateStatus(id: String, status: String, updatedAt: Long)

    @Query("UPDATE invoices SET pdfPath = :path, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updatePdf(id: String, path: String, updatedAt: Long)

    @Query("UPDATE invoices SET signaturePath = :path, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateSignature(id: String, path: String, updatedAt: Long)

    @Delete
    suspend fun delete(entity: InvoiceEntity)

    @Query("SELECT * FROM invoice_line_items WHERE invoiceId = :invoiceId ORDER BY position")
    suspend fun items(invoiceId: String): List<InvoiceLineItemEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertItem(item: InvoiceLineItemEntity)

    @Query("DELETE FROM invoice_line_items WHERE invoiceId = :invoiceId")
    suspend fun deleteItems(invoiceId: String)

    @Query("SELECT * FROM invoice_images WHERE invoiceId = :invoiceId ORDER BY sortOrder")
    suspend fun images(invoiceId: String): List<InvoiceImageEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertImage(image: InvoiceImageEntity)

    @Query("DELETE FROM invoice_images WHERE id = :id")
    suspend fun deleteImage(id: String)
}

@Dao
interface TransactionDao {
    @Query("SELECT * FROM transactions WHERE businessId = :businessId ORDER BY occurredAt DESC")
    fun observeForBusiness(businessId: String): Flow<List<TransactionEntity>>

    @Query("SELECT * FROM transactions WHERE customerId = :customerId ORDER BY occurredAt DESC")
    fun observeForCustomer(customerId: String): Flow<List<TransactionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: TransactionEntity)

    @Delete
    suspend fun delete(entity: TransactionEntity)
}

@Dao
interface NoteDao {
    @Query("SELECT * FROM notes WHERE customerId = :customerId ORDER BY updatedAt DESC")
    fun observeForCustomer(customerId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE id = :id")
    suspend fun get(id: String): NoteEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: NoteEntity)

    @Delete
    suspend fun delete(entity: NoteEntity)
}

@Dao
interface FolderFileDao {
    @Query("SELECT * FROM folder_files WHERE customerId = :customerId AND folderType = :folderType ORDER BY createdAt DESC")
    fun observe(customerId: String, folderType: String): Flow<List<FolderFileEntity>>

    @Query("SELECT * FROM folder_files WHERE customerId = :customerId ORDER BY createdAt DESC")
    fun observeAll(customerId: String): Flow<List<FolderFileEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: FolderFileEntity)

    @Delete
    suspend fun delete(entity: FolderFileEntity)
}

@Dao
interface TemplateDao {
    @Query("SELECT * FROM invoice_templates WHERE businessId = :businessId ORDER BY name")
    fun observeForBusiness(businessId: String): Flow<List<InvoiceTemplateEntity>>

    @Query("SELECT * FROM invoice_templates WHERE businessId = :businessId ORDER BY name")
    suspend fun forBusiness(businessId: String): List<InvoiceTemplateEntity>

    @Query("SELECT * FROM invoice_templates WHERE id = :id")
    suspend fun get(id: String): InvoiceTemplateEntity?

    @Query("SELECT * FROM invoice_templates WHERE businessId = :businessId AND isDefault = 1 LIMIT 1")
    suspend fun defaultFor(businessId: String): InvoiceTemplateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: InvoiceTemplateEntity)

    @Query("UPDATE invoice_templates SET isDefault = 0 WHERE businessId = :businessId")
    suspend fun clearDefaults(businessId: String)
}

@Dao
interface SettingsDao {
    @Query("SELECT * FROM app_settings WHERE id = 1")
    fun observe(): Flow<AppSettingsEntity?>

    @Query("SELECT * FROM app_settings WHERE id = 1")
    suspend fun get(): AppSettingsEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: AppSettingsEntity)
}
