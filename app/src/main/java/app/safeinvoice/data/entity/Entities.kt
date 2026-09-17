package app.safeinvoice.data.entity

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

@Entity(tableName = "businesses")
data class BusinessEntity(
    @PrimaryKey val id: String,
    val name: String,
    val tradingName: String?,
    val registrationNumber: String?,
    val vatNumber: String?,
    val email: String,
    val phone: String,
    val addressLine1: String,
    val addressLine2: String?,
    val city: String,
    val province: String,
    val postalCode: String,
    val country: String = "South Africa",
    val bankName: String?,
    val bankAccountName: String?,
    val bankAccountNumber: String?,
    val bankBranchCode: String?,
    val logoPath: String?,
    val defaultCurrency: String = "ZAR",
    val defaultVatPercent: Double = 15.0,
    val invoicePrefix: String = "INV",
    val nextInvoiceNumber: Long = 1,
    val createdAt: Long,
    val updatedAt: Long,
    val isActive: Boolean = true,
)

@Entity(
    tableName = "customers",
    foreignKeys = [
        ForeignKey(
            entity = BusinessEntity::class,
            parentColumns = ["id"],
            childColumns = ["businessId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("businessId")],
)
data class CustomerEntity(
    @PrimaryKey val id: String,
    val businessId: String,
    val name: String,
    val contactName: String?,
    val email: String?,
    val phone: String?,
    val addressLine1: String?,
    val city: String?,
    val province: String?,
    val postalCode: String?,
    val vatNumber: String?,
    val notes: String?,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(
    tableName = "invoices",
    foreignKeys = [
        ForeignKey(
            entity = BusinessEntity::class,
            parentColumns = ["id"],
            childColumns = ["businessId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CustomerEntity::class,
            parentColumns = ["id"],
            childColumns = ["customerId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("businessId"), Index("customerId"), Index("status")],
)
data class InvoiceEntity(
    @PrimaryKey val id: String,
    val businessId: String,
    val customerId: String,
    val number: String,
    val status: String,
    val issueDate: Long,
    val dueDate: Long,
    val currency: String,
    val vatPercent: Double,
    val discountAmount: Double,
    val discountPercent: Double,
    val notes: String?,
    val terms: String?,
    val signaturePath: String?,
    val pdfPath: String?,
    val templateId: String?,
    val subtotal: Double,
    val vatAmount: Double,
    val total: Double,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(
    tableName = "invoice_line_items",
    foreignKeys = [
        ForeignKey(
            entity = InvoiceEntity::class,
            parentColumns = ["id"],
            childColumns = ["invoiceId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("invoiceId")],
)
data class InvoiceLineItemEntity(
    @PrimaryKey val id: String,
    val invoiceId: String,
    val position: Int,
    val description: String,
    val quantity: Double,
    val unitPrice: Double,
    val taxable: Boolean = true,
)

@Entity(
    tableName = "invoice_images",
    foreignKeys = [
        ForeignKey(
            entity = InvoiceEntity::class,
            parentColumns = ["id"],
            childColumns = ["invoiceId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("invoiceId")],
)
data class InvoiceImageEntity(
    @PrimaryKey val id: String,
    val invoiceId: String,
    val path: String,
    val sortOrder: Int,
)

@Entity(
    tableName = "transactions",
    foreignKeys = [
        ForeignKey(
            entity = BusinessEntity::class,
            parentColumns = ["id"],
            childColumns = ["businessId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("businessId"), Index("customerId"), Index("invoiceId")],
)
data class TransactionEntity(
    @PrimaryKey val id: String,
    val businessId: String,
    val customerId: String?,
    val invoiceId: String?,
    val type: String,
    val amount: Double,
    val currency: String,
    val occurredAt: Long,
    val method: String?,
    val reference: String?,
    val notes: String?,
    val receiptPath: String?,
    val createdAt: Long,
)

@Entity(
    tableName = "notes",
    foreignKeys = [
        ForeignKey(
            entity = CustomerEntity::class,
            parentColumns = ["id"],
            childColumns = ["customerId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("businessId"), Index("customerId")],
)
data class NoteEntity(
    @PrimaryKey val id: String,
    val businessId: String,
    val customerId: String,
    val title: String,
    val body: String,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(
    tableName = "folder_files",
    indices = [Index("businessId"), Index("customerId"), Index("folderType")],
)
data class FolderFileEntity(
    @PrimaryKey val id: String,
    val businessId: String,
    val customerId: String,
    val folderType: String,
    val displayName: String,
    val mimeType: String,
    val relativePath: String,
    val sizeBytes: Long,
    val createdAt: Long,
)

@Entity(
    tableName = "invoice_templates",
    foreignKeys = [
        ForeignKey(
            entity = BusinessEntity::class,
            parentColumns = ["id"],
            childColumns = ["businessId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("businessId")],
)
data class InvoiceTemplateEntity(
    @PrimaryKey val id: String,
    val businessId: String,
    val name: String,
    val isDefault: Boolean,
    val primaryColor: Long,
    val accentColor: Long,
    val logoPath: String?,
    val layout: String,
    val showBankDetails: Boolean,
    val footerText: String?,
    val headerImagePath: String?,
    val extraImagePath: String?,
    val logoAlignment: String = LogoAlignment.LEFT.name,
    val marginPreset: String = MarginPreset.NORMAL.name,
    val picturePlacement: String = PicturePlacement.AFTER_ITEMS.name,
    val showSignatureLine: Boolean = true,
    val headerBanner: Boolean = true,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(tableName = "app_settings")
data class AppSettingsEntity(
    @PrimaryKey val id: Int = 1,
    val themeMode: String = ThemeMode.SYSTEM.name,
    val accentPalette: String = AccentPalette.FOREST.name,
    val activeBusinessId: String?,
)

data class InvoiceWithDetails(
    @Embedded val invoice: InvoiceEntity,
    @Relation(parentColumn = "id", entityColumn = "invoiceId")
    val items: List<InvoiceLineItemEntity>,
    @Relation(parentColumn = "id", entityColumn = "invoiceId")
    val images: List<InvoiceImageEntity>,
)

enum class InvoiceStatus { DRAFT, SENT, PAID, OVERDUE, CANCELLED }

enum class FolderType { INVOICES, RECEIPTS, EXCEL, IMAGES, NOTES }

enum class TransactionType { PAYMENT, REFUND, EXPENSE, RECEIPT }

enum class ThemeMode { LIGHT, DARK, SYSTEM }

enum class AccentPalette {
    FOREST,
    NAVY,
    EMERALD,
    AMBER,
    ROSE,
    SLATE,
    INDIGO,
    TEAL,
}

enum class TemplateLayout { CLASSIC, MODERN, COMPACT, LETTERHEAD, MINIMAL }

enum class LogoAlignment { LEFT, CENTER, RIGHT }

enum class MarginPreset { TIGHT, NORMAL, WIDE }

enum class PicturePlacement { HEADER, AFTER_ITEMS, FOOTER }
