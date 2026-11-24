package com.example.campusconnect

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Android-only secure session persistence without adding a third-party plugin. */
class MainActivity : FlutterActivity() {
    private val channelName = "campusconnect/secure_token"
    private val keyAlias = "campusconnect_session_aes_v1"
    private val preferences by lazy {
        getSharedPreferences("campusconnect_encrypted_session", MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> result.success(readToken())
                        "write" -> {
                            val token = call.argument<String>("token")
                            if (token.isNullOrEmpty()) {
                                result.error("INVALID_TOKEN", "Token must not be empty", null)
                            } else {
                                writeToken(token)
                                result.success(null)
                            }
                        }
                        "delete" -> {
                            preferences.edit().remove("blob").apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("STORAGE_UNAVAILABLE", "Android secure storage failed", null)
                }
            }
    }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(keyAlias, null)
        if (existing is SecretKey) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun writeToken(token: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
        val packed = cipher.iv + encrypted
        preferences.edit().putString("blob", Base64.encodeToString(packed, Base64.NO_WRAP)).apply()
    }

    private fun readToken(): String? {
        val packed = preferences.getString("blob", null) ?: return null
        return try {
            val bytes = Base64.decode(packed, Base64.DEFAULT)
            if (bytes.size <= 12) throw IllegalArgumentException("Invalid encrypted data")
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
        } catch (_: Exception) {
            // Android KeyStore keys cannot be restored from a different device.
            preferences.edit().remove("blob").apply()
            null
        }
    }
}
