package app.vaulty.vaulty

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.ByteArrayOutputStream
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Parcelable
import android.provider.OpenableColumns
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.util.UUID
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var renewalChannel: MethodChannel? = null
    private var openRenewals = false
    private val worker = Executors.newSingleThreadExecutor()
    private val root get() = File(filesDir, "incoming-encrypted").apply { mkdirs() }
    private val maximum = 50L * 1024 * 1024
    private val batchMaximum = 150L * 1024 * 1024
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "vaulty-incoming-v1"
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
        }.generateKey()
    }
    private fun encrypt(file: File, write: (java.io.OutputStream) -> Unit) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        file.outputStream().use { raw -> raw.write(cipher.iv); CipherOutputStream(raw,cipher).use(write) }
    }
    private fun decrypt(file: File): ByteArray = file.inputStream().use { raw ->
        val iv = ByteArray(12)
        check(raw.read(iv) == 12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,iv)) }
        CipherInputStream(raw,cipher).use { it.readBytes() }
    }
    private fun load(): MutableList<JSONObject> {
        val file = File(root,"manifest.bin")
        val rows = if (!file.exists()) JSONArray() else try { JSONArray(String(decrypt(file),Charsets.UTF_8)) } catch (_: Exception) { JSONArray() }
        val result = mutableListOf<JSONObject>()
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            if (System.currentTimeMillis() - row.optLong("created") < 24L*60*60*1000) result.add(row)
            else File(root,row.getString("id")+".bin").delete()
        }
        val active = result.map { it.getString("id")+".bin" }.toSet()
        root.listFiles()?.filter { it.name!="manifest.bin" && it.name !in active && System.currentTimeMillis()-it.lastModified()>24L*60*60*1000 }?.forEach { it.delete() }
        return result
    }
    private fun save(rows: List<JSONObject>) {
        val tmp = File(root,"manifest.tmp")
        encrypt(tmp) { it.write(JSONArray(rows).toString().toByteArray(Charsets.UTF_8)) }
        check(tmp.renameTo(File(root,"manifest.bin")))
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        renewalChannel=MethodChannel(engine.dartExecutor.binaryMessenger,"app.vaulty/renewals").also { bridge ->
            bridge.setMethodCallHandler { call,result ->
                if(call.method=="takeOpen") {val open=openRenewals;openRenewals=false;result.success(open)}
                else worker.execute {
                    try {
                        val value:Any?=when(call.method) {
                            "update" -> {Renewals.update(applicationContext,call.arguments as Map<*,*>);null}
                            "clear" -> {Renewals.clear(applicationContext);null}
                            "language" -> {Renewals.language(applicationContext,call.argument<String>("language") ?: "en");null}
                            "test" -> {Renewals.test(applicationContext,call.argument<String>("language") ?: "en");null}
                            "status" -> Renewals.status(applicationContext)
                            "check" -> {Renewals.check(applicationContext);null}
                            else -> error("Unknown reminder operation")
                        }
                        runOnUiThread {result.success(value)}
                    } catch(e:Exception) {runOnUiThread {result.error("renewals",e.message ?: "Could not update reminders",null)}}
                }
            }
        }
        channel = MethodChannel(engine.dartExecutor.binaryMessenger,"app.vaulty/incoming").also { channel ->
            channel.setMethodCallHandler { call, result ->
                worker.execute {
                    try {
                        val rows = load()
                        val id = call.argument<String>("id")
                        val value: Any? = when(call.method) {
                            "renderPdf" -> {
                                val bytes = call.argument<ByteArray>("bytes") ?: error("No PDF supplied")
                                check(bytes.size <= maximum)
                                val temp = File.createTempFile("vaulty-preview-", ".pdf", cacheDir)
                                try {
                                    temp.writeBytes(bytes)
                                    PdfRenderer(ParcelFileDescriptor.open(temp,ParcelFileDescriptor.MODE_READ_ONLY)).use { pdf ->
                                        check(pdf.pageCount > 0)
                                        pdf.openPage(0).use { page ->
                                            val scale = minOf(1200.0/page.width,1600.0/page.height)
                                            val bitmap=Bitmap.createBitmap((page.width*scale).toInt().coerceAtLeast(1),(page.height*scale).toInt().coerceAtLeast(1),Bitmap.Config.ARGB_8888)
                                            try {
                                                bitmap.eraseColor(android.graphics.Color.WHITE)
                                                page.render(bitmap,null,null,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                                ByteArrayOutputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.PNG,100,out);out.toByteArray() }
                                            } finally { bitmap.recycle() }
                                        }
                                    }
                                } finally { temp.delete() }
                            }
                            "pending" -> rows.map { row -> mapOf("id" to row.getString("id"),"name" to row.getString("name"),"size" to row.optLong("size"),"mime" to row.optString("mime"),"error" to row.optString("error")) }
                            "read" -> {
                                val row = rows.firstOrNull { it.getString("id")==id } ?: error("This import expired. Share it into Vaulty again.")
                                check(row.optString("error").isEmpty()) { row.optString("error") }
                                val file = File(root,row.getString("id")+".bin")
                                check(file.length() <= maximum+64) { "File exceeds 50 MB." }
                                decrypt(file)
                            }
                            "discard" -> { rows.removeAll { it.getString("id")==id }; if (id != null && Regex("[a-f0-9-]{36}").matches(id)) File(root,"$id.bin").delete(); save(rows); null }
                            "clear" -> { root.deleteRecursively(); cacheDir.listFiles()?.filter { it.name.startsWith("vaulty-preview-") }?.forEach { it.delete() }; null }
                            else -> error("Unknown import operation")
                        }
                        runOnUiThread { result.success(value) }
                    } catch (e: Exception) { runOnUiThread { result.error("import",e.message ?: "Could not read shared files",null) } }
                }
            }
        }
    }
    override fun onCreate(state: Bundle?) { super.onCreate(state); receiveRenewal(intent); receive(intent) }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); receiveRenewal(intent); receive(intent) }
    private fun receiveRenewal(intent:Intent?) {
        if(intent?.getBooleanExtra("vaulty_open_home",false)==true) {
            openRenewals=true;intent.removeExtra("vaulty_open_home");renewalChannel?.invokeMethod("openHome",null)
        }
    }
    @Suppress("DEPRECATION")
    private fun receive(shared: Intent?) {
        if (shared == null || (shared.action != Intent.ACTION_SEND && shared.action != Intent.ACTION_SEND_MULTIPLE)) return
        val uris = mutableListOf<Uri>()
        try {
            if (shared.action == Intent.ACTION_SEND_MULTIPLE) uris.addAll(shared.getParcelableArrayListExtra<Parcelable>(Intent.EXTRA_STREAM)?.filterIsInstance<Uri>() ?: emptyList())
            else (shared.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri)?.let { uris.add(it) }
            shared.clipData?.let { data -> for (i in 0 until data.itemCount) data.getItemAt(i).uri?.let { uris.add(it) } }
        } catch (_: Exception) { uris.clear() }
        shared.action = null // Do not duplicate this intent on activity recreation.
        worker.execute {
            val rows = load()
            val incoming = uris.distinct()
            if (incoming.isEmpty()) rows.add(JSONObject().put("id",UUID.randomUUID().toString()).put("name","No document attached").put("created",System.currentTimeMillis()).put("error","Share a file attachment, not just text or a link."))
            var total = rows.sumOf { it.optLong("size") }
            val available = (20 - rows.size).coerceAtLeast(0)
            for (uri in incoming.take(available)) {
                val id = UUID.randomUUID().toString()
                val row = JSONObject().put("id",id).put("name","Shared document").put("created",System.currentTimeMillis())
                val file = File(root,"$id.bin")
                try {
                    check(rows.size < 20) { "Review or remove pending files first (20 file limit)." }
                    check(uri.scheme=="content") { "This app did not provide a readable content attachment. Save it to Files and share again." }
                    row.put("mime",contentResolver.getType(uri) ?: shared.type ?: "application/octet-stream")
                    contentResolver.query(uri,arrayOf(OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE),null,null,null)?.use { cursor ->
                        if(cursor.moveToFirst()) {
                            val name = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if(name>=0 && !cursor.isNull(name)) row.put("name",cursor.getString(name).take(240))
                            val size = cursor.getColumnIndex(OpenableColumns.SIZE)
                            if(size>=0 && !cursor.isNull(size)) check(cursor.getLong(size) <= maximum) { "Choose a file up to 50 MB." }
                        }
                    }
                    var count = 0L
                    contentResolver.openInputStream(uri)?.use { input ->
                        encrypt(file) { output ->
                            val buffer = ByteArray(64*1024)
                            while(true) {
                                val read = input.read(buffer); if(read<0) break
                                count+=read
                                check(count <= maximum && total+count <= batchMaximum) { "Limit: 50 MB per file and 150 MB per pending batch." }
                                output.write(buffer,0,read)
                            }
                        }
                    } ?: error("The sending app did not allow access to this file.")
                    check(count>0) { "Empty file." }
                    row.put("size",count); total+=count
                } catch (e:Exception) { file.delete(); row.put("size",0).put("error",e.message ?: "Could not read attachment.") }
                rows.add(row)
            }
            if(incoming.size>available && rows.none { it.optString("name")=="Additional files not imported" }) rows.add(JSONObject().put("id",UUID.randomUUID().toString()).put("name","Additional files not imported").put("created",System.currentTimeMillis()).put("error","At most 20 pending files are allowed. Finish or discard this batch, then share the remaining originals again."))
            try { save(rows); runOnUiThread { channel?.invokeMethod("changed",null) } } catch (_:Exception) { /* No upload occurs unless persisted intake can be reviewed. */ }
        }
    }
}
