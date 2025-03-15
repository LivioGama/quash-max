package com.quash.testapp

import com.quash.bugs.sdkhelper.Quash
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

object NetworkManager {

    val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .addInterceptor(Quash.getInstance().networkInterceptor)
            .build()
    }

    val retrofit: Retrofit by lazy {
        Retrofit.Builder()
            .baseUrl("https://api.example.com/")
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }
}
