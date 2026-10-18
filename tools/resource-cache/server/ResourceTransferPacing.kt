package jp.assasans.protanki.server.resources

import io.ktor.http.*
import io.ktor.http.content.OutgoingContent
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.ApplicationSendPipeline
import io.ktor.utils.io.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import mu.KotlinLogging

/** Keep bulk AIR cache downloads inside the existing public resource budget. */
object ResourceTransferPacing {
  private val logger = KotlinLogging.logger { }

  fun install(application: Application, gate: Semaphore, bytesPerSecond: Long, chunkBytes: Int) {
    application.sendPipeline.intercept(ApplicationSendPipeline.Transform) {
      val cacheRedirect = ResourceCacheHosting.redirect(call.request.path())
      if(cacheRedirect != null) {
        proceedWith(cacheRedirect)
        return@intercept
      }
      val content = subject as? OutgoingContent.ReadChannelContent ?: return@intercept
      if(!call.request.path().startsWith("/assets/")) return@intercept
      // Use the connection's address, never a forwarded/header-supplied address.
      if(jp.assasans.protanki.server.security.HttpSecurity.isLoopback(call.request.local.remoteHost)) return@intercept

      proceedWith(object : OutgoingContent.WriteChannelContent() {
        override val contentType: ContentType? get() = content.contentType
        override val contentLength: Long? get() = content.contentLength
        override val status: HttpStatusCode? get() = content.status
        override val headers: Headers get() = content.headers

        override suspend fun writeTo(channel: ByteWriteChannel) {
          gate.withPermit {
            val started = System.nanoTime()
            var transferred = 0L
            val input = content.readFrom()
            try {
              val buffer = ByteArray(chunkBytes)
              while(true) {
                val read = input.readAvailable(buffer, 0, buffer.size)
                if(read < 0) break
                if(read == 0) continue
                transferred += read
                if(bytesPerSecond > 0) {
                  val remainingNanos = transferred * 1_000_000_000L / bytesPerSecond - (System.nanoTime() - started)
                  if(remainingNanos > 0) delay((remainingNanos + 999_999L) / 1_000_000L)
                }
                channel.writeFully(buffer, 0, read)
                channel.flush()
              }
            } finally {
              input.cancel(null)
            }
            if(transferred >= 1024 * 1024) logger.info {
              "[RESOURCE-TRANSFER] paced asset path=${call.request.path()} bytes=$transferred " +
                "durationMs=${(System.nanoTime() - started) / 1_000_000L} bytesPerSecond=$bytesPerSecond"
            }
          }
        }
      })
    }
  }
}
