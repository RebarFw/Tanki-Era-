package jp.assasans.protanki.server.resources

import io.ktor.http.*
import io.ktor.http.content.OutgoingContent
import java.net.URLEncoder
import java.net.URLDecoder
import java.util.Locale
import java.util.Properties
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import jp.assasans.protanki.server.IResourceManager

/** Cache payloads are served exclusively by GitHub, including legacy HTTP URLs. */
object ResourceCacheHosting : KoinComponent {
  private val resourceManager: IResourceManager by inject()
  private const val prefix = "/assets/resource-cache/v1/"
  private val allowed = Regex("https://github\\.com/RebarFw/Tanki-Era-/releases/download/resource-cache-v[0-9]+/(?:[0-9a-f]{64}\\.tpk|manifest-[0-9a-f]{64}\\.(?:json|sha256))")

  private fun lookup(key: String): String? {
    val index = resourceManager.get("assets/resource-cache/v1/github-downloads.properties").toFile()
    if(!index.isFile) return null
    val entries = Properties()
    index.reader(Charsets.UTF_8).use { entries.load(it) }
    return entries.getProperty(key)?.takeIf { allowed.matches(it) }
  }

  @JvmStatic fun manifestUrl(base: String, sha: String): String {
    require(Regex("[0-9a-f]{64}").matches(sha))
    val url = lookup("manifest-$sha.json") ?: error("Cache manifest has not been published to GitHub")
    // This fragment is local cache identity only; the client strips it before HTTP.
    return url + "#cache-origin=" + URLEncoder.encode(base + prefix.removePrefix("/"), "UTF-8").replace("+", "%20")
  }

  @JvmStatic fun redirect(rawPath: String): OutgoingContent? {
    // Static Windows paths are case insensitive; normalize encoded and dot paths
    // as well so an alternative spelling cannot expose local bundle bytes.
    val segments = mutableListOf<String>()
    val decoded = runCatching { URLDecoder.decode(rawPath, "UTF-8") }.getOrDefault(rawPath)
    decoded.replace('\\', '/').split('/').forEach {
      when(it) { "", "." -> Unit; ".." -> if(segments.isNotEmpty()) segments.removeAt(segments.lastIndex); else -> segments.add(it) }
    }
    val path = "/" + segments.joinToString("/").lowercase(Locale.ROOT)
    if(!path.startsWith("/assets/resource-cache/")) return null
    val url = if(path.startsWith(prefix)) lookup(path.removePrefix(prefix)) else null
    return object : OutgoingContent.NoContent() {
      override val status = if(url == null) HttpStatusCode.NotFound else HttpStatusCode.Found
      override val headers = Headers.build {
        append(HttpHeaders.CacheControl, "no-store")
        if(url != null) append(HttpHeaders.Location, url)
      }
    }
  }
}
