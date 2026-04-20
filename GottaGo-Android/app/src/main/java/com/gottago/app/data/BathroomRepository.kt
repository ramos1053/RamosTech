package com.gottago.app.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.gottago.app.model.Bathroom
import com.gottago.app.model.Review
import com.gottago.app.model.sampleBathrooms

class BathroomRepository(context: Context) {

    private val prefs = context.getSharedPreferences("gottago_prefs", Context.MODE_PRIVATE)
    private val gson  = Gson()

    private val bathroomsKey  = "gottago_bathrooms_v1"
    private val favOrderKey   = "gottago_favorites_order"

    fun loadBathrooms(): List<Bathroom> {
        val json = prefs.getString(bathroomsKey, null) ?: return sampleBathrooms
        return try {
            val type = object : TypeToken<List<Bathroom>>() {}.type
            gson.fromJson<List<Bathroom>>(json, type) ?: sampleBathrooms
        } catch (e: Exception) {
            sampleBathrooms
        }
    }

    fun saveBathrooms(bathrooms: List<Bathroom>) {
        prefs.edit().putString(bathroomsKey, gson.toJson(bathrooms)).apply()
    }

    fun loadFavoritesOrder(): List<String> {
        val json = prefs.getString(favOrderKey, null) ?: return emptyList()
        return try {
            val type = object : TypeToken<List<String>>() {}.type
            gson.fromJson<List<String>>(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveFavoritesOrder(order: List<String>) {
        prefs.edit().putString(favOrderKey, gson.toJson(order)).apply()
    }

    fun addReview(bathrooms: MutableList<Bathroom>, bathroomId: String, review: Review): List<Bathroom> {
        val index = bathrooms.indexOfFirst { it.id == bathroomId }
        if (index < 0) return bathrooms
        val updated = bathrooms[index].copy(reviews = bathrooms[index].reviews + review)
        bathrooms[index] = updated
        return bathrooms.toList()
    }
}
