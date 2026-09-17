# App + Room entities
-keep class app.safeinvoice.** { *; }
-keep class androidx.room.** { *; }

# Apache POI / XMLBeans (Excel .xls/.xlsx)
-keep class org.apache.poi.** { *; }
-keep class org.apache.xmlbeans.** { *; }
-keep class org.openxmlformats.** { *; }
-keep class com.microsoft.schemas.** { *; }
-keep class org.etsi.** { *; }
-keep class schemasMicrosoftComOfficeOffice.** { *; }
-keep class schemasMicrosoftComOfficeExcel.** { *; }
-keep class schemasMicrosoftComVml.** { *; }
-dontwarn org.apache.poi.**
-dontwarn org.apache.xmlbeans.**
-dontwarn org.openxmlformats.**
-dontwarn com.microsoft.schemas.**
-dontwarn org.etsi.**
-dontwarn org.etd.dev.**
-dontwarn org.w3c.dom.**
-dontwarn javax.xml.**
-dontwarn org.bouncycastle.**
-dontwarn org.apache.logging.**
-dontwarn org.apache.commons.logging.**
-dontwarn org.apache.commons.compress.**
-dontwarn org.apache.commons.codec.**
-dontwarn org.apache.commons.collections4.**
-dontwarn org.apache.commons.io.**
-dontwarn org.apache.commons.math3.**
-dontwarn com.zaxxer.sparsebits.**
-dontwarn org.apache.batik.**
-dontwarn org.apache.xml.security.**
-dontwarn java.awt.**
-dontwarn javax.imageio.**
-dontwarn javax.swing.**

-dontwarn kotlinx.coroutines.**
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
