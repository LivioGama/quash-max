package com.quash.testapp

import android.app.Application
import com.quash.bugs.sdkhelper.Quash

class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Quash.initialize(
            this,
            "YOUR_APPLICATION_KEY",
            true
        )
    }
}
