package com.mono.container.engine

sealed class DownloadOutcome {
    object Saved : DownloadOutcome()
    object Kept : DownloadOutcome()
    data class Failed(val reason: RouteFailure?) : DownloadOutcome()
}

class DownloadFetcher(private val context: android.content.Context) {
    fun run(config: SiteConfig, pending: PendingDownload, decisionName: String): DownloadOutcome {
        val route = config.currentRoute()
        if (route is Route.Refused) return DownloadOutcome.Failed(route.failure)
        val fileName = sanitizeFileName(pending.fileName)
        return when (decisionName) {
            "keepInContainer" -> runCatching { keepInContainer(route, config, pending, fileName) }
                .getOrElse { DownloadOutcome.Failed(null) }
            "saveToDevice" -> when (route) {
                is Route.Direct -> runCatching { saveViaDownloadManager(config, pending, fileName) }
                    .getOrElse { DownloadOutcome.Failed(null) }
                is Route.Proxy -> runCatching { saveViaMediaStore(route, pending, fileName) }
                    .getOrElse { DownloadOutcome.Failed(null) }
                is Route.Refused -> error("handled above")
            }
            else -> error("unsupported download decision")
        }
    }

    private fun keepInContainer(route: Route, config: SiteConfig, pending: PendingDownload, fileName: String): DownloadOutcome {
        val dir = java.io.File(context.filesDir, "downloads/${config.profileId}")
        dir.mkdirs()
        val target = uniqueFile(dir, fileName)
        fetchTo(route, pending, target)
        val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", target)
        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
            setDataAndType(uri, pending.mimeType)
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
        return DownloadOutcome.Kept
    }

    private fun saveViaMediaStore(route: Route, pending: PendingDownload, fileName: String): DownloadOutcome {
        val temp = java.io.File.createTempFile("dl", null, context.cacheDir)
        return try {
            fetchTo(route, pending, temp)
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(android.provider.MediaStore.Downloads.MIME_TYPE, pending.mimeType)
            }
            val uri = context.contentResolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return DownloadOutcome.Failed(null)
            val output = context.contentResolver.openOutputStream(uri) ?: return DownloadOutcome.Failed(null)
            output.use { out -> temp.inputStream().use { input -> input.copyTo(out) } }
            DownloadOutcome.Saved
        } finally { temp.delete() }
    }

    private fun saveViaDownloadManager(config: SiteConfig, pending: PendingDownload, fileName: String): DownloadOutcome {
        val manager = context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
        val request = android.app.DownloadManager.Request(android.net.Uri.parse(pending.url))
            .setMimeType(pending.mimeType)
            .addRequestHeader("User-Agent", userAgentFor(config.userAgentMode, context))
            .setDestinationInExternalPublicDir(android.os.Environment.DIRECTORY_DOWNLOADS, fileName)
            .setNotificationVisibility(android.app.DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        android.webkit.CookieManager.getInstance().getCookie(pending.url)?.let { request.addRequestHeader("Cookie", it) }
        manager.enqueue(request)
        return DownloadOutcome.Saved
    }

    private fun fetchTo(route: Route, pending: PendingDownload, target: java.io.File) {
        val url = java.net.URL(pending.url)
        val port = if (url.port != -1) url.port else if (url.protocol == "https") 443 else 80
        val path = (url.path?.ifEmpty { "/" } ?: "/") + (url.query?.let { "?$it" } ?: "")
        val response = ProxyHttpClient.fetch(route, url.host, port, url.protocol == "https", "GET", path, emptyMap())
        java.io.FileOutputStream(target).use { output -> response.body.use { it.copyTo(output) } }
    }

    private fun uniqueFile(dir: java.io.File, fileName: String): java.io.File {
        val dot = fileName.lastIndexOf('.')
        val base = if (dot > 0) fileName.substring(0, dot) else fileName
        val ext = if (dot > 0) fileName.substring(dot) else ""
        var candidate = java.io.File(dir, fileName)
        var suffix = 1
        while (candidate.exists()) { candidate = java.io.File(dir, "$base ($suffix)$ext"); suffix++ }
        return candidate
    }
}

fun sanitizeFileName(name: String): String {
    val stripped = name.replace(Regex("[/\\\\]"), "_").replace("..", "_").trimStart('.')
    return stripped.ifEmpty { "download" }
}
