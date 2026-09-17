package app.safeinvoice

import android.app.Application
import app.safeinvoice.di.AppContainer

class SafeInvoiceApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
