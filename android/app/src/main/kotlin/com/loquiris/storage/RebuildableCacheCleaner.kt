package com.loquiris.storage

import java.io.File
import java.io.IOException
import java.nio.file.FileVisitResult
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.SimpleFileVisitor
import java.nio.file.attribute.BasicFileAttributes

data class RebuildableCacheCleanupReceipt(
    val filesDeleted: Int,
    val bytesDeleted: Long,
)

sealed interface RebuildableCacheCleanupResult {
    data class Success(
        val receipt: RebuildableCacheCleanupReceipt,
    ) : RebuildableCacheCleanupResult

    data class Failure(
        val code: String,
        val filesDeleted: Int,
        val bytesDeleted: Long,
    ) : RebuildableCacheCleanupResult
}

fun interface RebuildableCacheCleanup {
    fun clear(): RebuildableCacheCleanupResult
}

class RebuildableCacheCleaner(
    cacheRoot: File,
) : RebuildableCacheCleanup {
    private val cacheRoot = cacheRoot.toPath().toAbsolutePath().normalize()

    override fun clear(): RebuildableCacheCleanupResult {
        var filesDeleted = 0
        var bytesDeleted = 0L
        return try {
            for (directoryName in ALLOWLISTED_DIRECTORIES) {
                val candidate = cacheRoot.resolve(directoryName).normalize()
                check(candidate.parent == cacheRoot)
                if (!Files.exists(candidate, java.nio.file.LinkOption.NOFOLLOW_LINKS)) continue
                Files.walkFileTree(
                    candidate,
                    object : SimpleFileVisitor<Path>() {
                        override fun visitFile(
                            file: Path,
                            attributes: BasicFileAttributes,
                        ): FileVisitResult {
                            val regularFileBytes = attributes.size().takeIf {
                                attributes.isRegularFile
                            }
                            Files.delete(file)
                            if (regularFileBytes != null) {
                                filesDeleted += 1
                                bytesDeleted += regularFileBytes
                            }
                            return FileVisitResult.CONTINUE
                        }

                        override fun visitFileFailed(
                            file: Path,
                            exception: IOException,
                        ): FileVisitResult = throw exception

                        override fun postVisitDirectory(
                            directory: Path,
                            exception: IOException?,
                        ): FileVisitResult {
                            if (exception != null) throw exception
                            Files.delete(directory)
                            return FileVisitResult.CONTINUE
                        }
                    },
                )
            }
            RebuildableCacheCleanupResult.Success(
                RebuildableCacheCleanupReceipt(filesDeleted, bytesDeleted),
            )
        } catch (_: IOException) {
            RebuildableCacheCleanupResult.Failure(
                code = "rebuildable_cache_cleanup_failed",
                filesDeleted = filesDeleted,
                bytesDeleted = bytesDeleted,
            )
        } catch (_: SecurityException) {
            RebuildableCacheCleanupResult.Failure(
                code = "rebuildable_cache_cleanup_failed",
                filesDeleted = filesDeleted,
                bytesDeleted = bytesDeleted,
            )
        }
    }

    private companion object {
        val ALLOWLISTED_DIRECTORIES =
            listOf("pcm", "waveforms", "search_indexes", "failed_jobs")
    }
}
