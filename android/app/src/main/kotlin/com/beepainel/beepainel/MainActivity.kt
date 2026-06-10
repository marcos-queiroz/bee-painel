package com.beepainel.beepainel

import android.app.ActivityManager
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "beepainel/platform"

    // Quando o modo kiosque pede o Lock Task, reentramos nele em onResume caso
    // o sistema o tenha derrubado (ex.: ao voltar de um dialogo/teclado).
    private var lockTaskRequested = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(isTelevision())
                    "startLockTask" -> {
                        lockTaskRequested = true
                        result.success(startLockTaskSafe())
                    }
                    "stopLockTask" -> {
                        lockTaskRequested = false
                        result.success(stopLockTaskSafe())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        // Se o kiosque esta ativo mas o sistema saiu do Lock Task, reentra.
        if (lockTaskRequested && !isInLockTaskMode()) {
            startLockTaskSafe()
        }
    }

    /// Entra em Lock Task Mode (fixacao de tela). Bloqueia HOME e a troca de
    /// apps. Sem provisionamento de Device Owner, o Android entra no modo de
    /// "fixacao de tela" pedida pelo app, que ainda bloqueia o HOME.
    private fun startLockTaskSafe(): Boolean {
        return try {
            if (!isInLockTaskMode()) {
                startLockTask()
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun stopLockTaskSafe(): Boolean {
        return try {
            if (isInLockTaskMode()) {
                stopLockTask()
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isInLockTaskMode(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            am.isInLockTaskMode
        }
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }
        val pm = packageManager
        if (pm.hasSystemFeature("android.software.leanback") ||
            pm.hasSystemFeature("android.hardware.type.television")
        ) {
            return true
        }
        // Muitos TV boxes Android genericos nao se declaram como TV nem leanback,
        // mas tambem nao tem tela sensivel ao toque -> tratamos como TV.
        return !pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }
}
