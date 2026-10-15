package app.vaulty.vaulty

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.Duration
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONArray
import org.json.JSONObject

// Pure calendar-day rules: no 24-hour/DST arithmetic and no exact-alarm permission.
internal object RenewalRules {
    fun due(expiry: String, today: LocalDate, days: Long): Boolean =
        try { !LocalDate.parse(expiry).minusDays(days).isAfter(today) } catch (_: Exception) { false }
}
object Renewals {
    private val lock=Any()
    private const val periodic="vaulty-renewals-periodic-v4"
    private const val morning="vaulty-renewals-morning-v4"
    private const val immediate="vaulty-renewals-now-v4"
    private const val channelId="vaulty-renewals-v4"
    private const val notificationId=41004
    private fun file(c:Context)=File(c.filesDir,"renewals-v4.enc")
    private fun key():SecretKey {
        val store=KeyStore.getInstance("AndroidKeyStore").apply {load(null)}
        val alias="vaulty-renewals-v4"
        (store.getKey(alias,null) as? SecretKey)?.let {return it}
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
        }.generateKey()
    }
    private fun read(c:Context):JSONObject {
        val f=file(c);if(!f.exists()) return JSONObject()
        val data=f.readBytes();check(data.size>=28)
        val cipher=Cipher.getInstance("AES/GCM/NoPadding").apply {init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,data.copyOfRange(0,12)));updateAAD("vaulty-renewals-v4".toByteArray())}
        return JSONObject(String(cipher.doFinal(data.copyOfRange(12,data.size)),Charsets.UTF_8))
    }
    private fun write(c:Context,state:JSONObject) {
        val cipher=Cipher.getInstance("AES/GCM/NoPadding").apply {init(Cipher.ENCRYPT_MODE,key());updateAAD("vaulty-renewals-v4".toByteArray())}
        val tmp=File(c.filesDir,"renewals-v4.tmp")
        tmp.outputStream().use {it.write(cipher.iv);it.write(cipher.doFinal(state.toString().toByteArray(Charsets.UTF_8)));it.flush()}
        check(tmp.renameTo(file(c)))
    }
    private fun channel(c:Context,hi:Boolean) {
        if(Build.VERSION.SDK_INT>=26) c.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(channelId,if(hi) "दस्तावेज़ नवीनीकरण" else "Document renewals",NotificationManager.IMPORTANCE_DEFAULT).apply {description=if(hi) "इस डिवाइस पर सुरक्षित नवीनीकरण अनुस्मारक" else "Private renewal reminders on this device";lockscreenVisibility=NotificationCompat.VISIBILITY_PRIVATE})
    }
    fun permitted(c:Context):Boolean {
        if(Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(c,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) return false
        if(!NotificationManagerCompat.from(c).areNotificationsEnabled()) return false
        if(Build.VERSION.SDK_INT>=26 && c.getSystemService(NotificationManager::class.java).getNotificationChannel(channelId)?.importance==NotificationManager.IMPORTANCE_NONE) return false
        return true
    }
    fun update(c:Context,args:Map<*,*>) {
        val owner=MessageDigest.getInstance("SHA-256").digest((args["owner"] as String).toByteArray()).joinToString("") {"%02x".format(it)}
        synchronized(lock) {
            val old=try {read(c)} catch(_:Exception) {JSONObject()}
            val same=old.optString("owner")==owner
            if(!same) NotificationManagerCompat.from(c).cancel(notificationId)
            val state=JSONObject().put("owner",owner).put("enabled",args["enabled"]==true).put("days",(args["days"] as Number).toInt().coerceIn(1,365)).put("language",args["language"] ?: "en").put("dates",JSONArray(args["dates"] as List<*>)).put("syncedAt",System.currentTimeMillis())
            if(same) {state.put("notifiedDay",old.optString("notifiedDay"));state.put("lastCheck",old.optLong("lastCheck"))}
            write(c,state);channel(c,state.optString("language")=="hi")
        }
        if(args["enabled"]!=true) {cancelJobs(c);NotificationManagerCompat.from(c).cancel(notificationId);return}
        WorkManager.getInstance(c).enqueueUniquePeriodicWork(periodic,ExistingPeriodicWorkPolicy.UPDATE,PeriodicWorkRequestBuilder<RenewalWorker>(6,TimeUnit.HOURS).addTag("periodic").build()).result.get()
        scheduleMorning(c,true)
        enqueueCheck(c)
    }
    fun language(c:Context,value:String) = synchronized(lock) {
        val state=read(c);if(!state.has("owner")) return@synchronized
        state.put("language",value);write(c,state);channel(c,value=="hi")
    }
    private fun cancelJobs(c:Context) {
        val wm=WorkManager.getInstance(c)
        for(name in listOf(periodic,morning,immediate)) wm.cancelUniqueWork(name).result.get()
    }
    fun clear(c:Context) {
        synchronized(lock) {file(c).delete();File(c.filesDir,"renewals-v4.tmp").delete();NotificationManagerCompat.from(c).cancel(notificationId)}
        cancelJobs(c)
    }
    fun enqueueCheck(c:Context) {
        WorkManager.getInstance(c).enqueueUniqueWork(immediate,ExistingWorkPolicy.REPLACE,OneTimeWorkRequestBuilder<RenewalWorker>().build()).result.get()
    }
    fun scheduleMorning(c:Context,replace:Boolean=false) {
        val enabled=synchronized(lock) {try {read(c).optBoolean("enabled")} catch(_:Exception) {false}}
        if(!enabled) return
        val now=ZonedDateTime.now()
        var next=now.toLocalDate().atTime(9,0).atZone(now.zone)
        if(!next.isAfter(now)) next=next.plusDays(1)
        WorkManager.getInstance(c).enqueueUniqueWork(morning,if(replace) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,OneTimeWorkRequestBuilder<RenewalWorker>().setInitialDelay(Duration.between(now,next).toMillis(),TimeUnit.MILLISECONDS).build()).result.get()
    }
    fun check(c:Context)=synchronized(lock) {
        val state=read(c)
        if(!state.optBoolean("enabled")) return@synchronized
        val now=ZonedDateTime.now();val today=now.toLocalDate()
        val dates=state.optJSONArray("dates") ?: JSONArray()
        var count=0
        for(i in 0 until dates.length()) if(RenewalRules.due(dates.getString(i),today,state.optLong("days",30))) count++
        state.put("lastCheck",System.currentTimeMillis())
        if(count>0 && now.hour>=9 && state.optString("notifiedDay")!=today.toString() && permitted(c)) {
            post(c,state.optString("language")=="hi",count,false)
            state.put("notifiedDay",today.toString())
        }
        if(count==0) NotificationManagerCompat.from(c).cancel(notificationId)
        write(c,state)
    }
    private fun post(c:Context,hi:Boolean,count:Int,test:Boolean) {
        channel(c,hi);check(permitted(c)) {if(hi) "Android सेटिंग में सूचनाएँ चालू करें।" else "Allow notifications and the renewal channel in Android settings."}
        val intent=Intent(c,MainActivity::class.java).putExtra("vaulty_open_home",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending=PendingIntent.getActivity(c,41004,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val title=if(test) {if(hi) "Vaulty की परीक्षण सूचना" else "Vaulty test notification"} else {if(hi) "नवीनीकरण का समय" else "A renewal needs your attention"}
        val body=if(test) {if(hi) "सूचनाएँ चालू हैं। अपना वॉल्ट खोलने के लिए टैप करें।" else "Notifications are available. Tap to open your vault."} else {if(hi) "नवीनीकरण की ज़रूरत वाले दस्तावेज़: $count। जाँचने के लिए Vaulty खोलें।" else if(count==1) "1 document needs renewal. Open Vaulty to review it." else "$count documents need renewal. Open Vaulty to review them."}
        val n=NotificationCompat.Builder(c,channelId).setSmallIcon(R.drawable.ic_stat_vaulty).setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)).setAutoCancel(true).setContentIntent(pending).setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setOnlyAlertOnce(false).build()
        NotificationManagerCompat.from(c).notify(if(test) notificationId+1 else notificationId,n)
    }
    fun test(c:Context,language:String)=synchronized(lock) {post(c,language=="hi",0,true)}
    fun status(c:Context):Map<String,Any> = synchronized(lock) {
        val state=try {read(c)} catch(_:Exception) {JSONObject()}
        mapOf("allowed" to permitted(c),"enabled" to state.optBoolean("enabled"),"lastCheck" to state.optLong("lastCheck"),"syncedAt" to state.optLong("syncedAt"),"count" to (state.optJSONArray("dates")?.length() ?: 0))
    }
}
class RenewalWorker(context:Context,params:WorkerParameters):Worker(context,params) {
    override fun doWork():Result = try {Renewals.check(applicationContext);if(tags.contains("periodic")) Renewals.scheduleMorning(applicationContext);Result.success()} catch(_:Exception) {Result.retry()}
}
class RenewalBootReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        val pending=goAsync()
        Thread {try {Renewals.scheduleMorning(context,true);Renewals.enqueueCheck(context)} finally {pending.finish()}}.start()
    }
}
