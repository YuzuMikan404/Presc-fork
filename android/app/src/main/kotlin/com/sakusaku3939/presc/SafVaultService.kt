package com.sakusaku3939.presc

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns

class SafVaultService(context: Context) {
    private val resolver = context.contentResolver

    fun getDisplayName(uri: Uri): String {
        val treeDocumentId = runCatching {
            DocumentsContract.getTreeDocumentId(uri)
        }.getOrNull()

        if (treeDocumentId != null) {
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                uri,
                treeDocumentId,
            )
            runCatching {
                resolver.query(
                    documentUri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(0) else null
                }
            }.getOrNull()?.takeIf { it.isNotBlank() }?.let { return it }
        }

        return treeDocumentId
            ?.substringAfterLast(':')
            ?.substringAfterLast('/')
            ?.takeIf { it.isNotBlank() }
            ?: "Vault"
    }

    fun listDocuments(treeUri: Uri): List<Map<String, Any?>> {
        val output = mutableListOf<Map<String, Any?>>()
        val visited = mutableSetOf<String>()
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        walk(treeUri, rootDocumentId, "", output, visited)
        return output
    }

    private fun walk(
        treeUri: Uri,
        parentDocumentId: String,
        parentPath: String,
        output: MutableList<Map<String, Any?>>,
        visited: MutableSet<String>,
    ) {
        if (!visited.add(parentDocumentId)) return

        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            parentDocumentId,
        )
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_FLAGS,
        )

        val directories = mutableListOf<Pair<String, String>>()
        resolver.query(childrenUri, columns, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            val modifiedIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            )
            val sizeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_SIZE,
            )
            val flagsIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_FLAGS,
            )

            while (cursor.moveToNext()) {
                val documentId = cursor.getString(idIndex)
                val name = cursor.getString(nameIndex) ?: continue
                val mimeType = cursor.getString(mimeIndex)
                val isDirectory = mimeType == DocumentsContract.Document.MIME_TYPE_DIR
                if (isDirectory && name == ".obsidian") continue
                val relativePath = if (parentPath.isEmpty()) name else "$parentPath/$name"
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    documentId,
                )

                if (isDirectory || isMarkdown(name, mimeType)) {
                    output.add(
                        mapOf(
                            "uri" to documentUri.toString(),
                            "documentId" to documentId,
                            "name" to name,
                            "relativePath" to relativePath,
                            "mimeType" to mimeType,
                            "isDirectory" to isDirectory,
                            "lastModified" to cursor.getLong(modifiedIndex),
                            "size" to cursor.getLong(sizeIndex),
                            "canWrite" to (
                                cursor.getInt(flagsIndex) and
                                    DocumentsContract.Document.FLAG_SUPPORTS_WRITE != 0
                                ),
                        ),
                    )
                }

                if (isDirectory) {
                    directories.add(documentId to relativePath)
                }
            }
        }

        // Some cloud-backed document providers do not support nested queries
        // while the parent cursor is still open.
        directories.forEach { (documentId, relativePath) ->
            walk(treeUri, documentId, relativePath, output, visited)
        }
    }

    fun readText(uri: Uri): String {
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Unable to open the selected document.")
        return bytes.toString(Charsets.UTF_8).removePrefix("\uFEFF")
    }

    fun writeText(uri: Uri, content: String) {
        resolver.openOutputStream(uri, "wt")?.bufferedWriter(Charsets.UTF_8)?.use { writer ->
            writer.write(content)
        } ?: throw IllegalStateException("This document provider does not allow writing.")
    }

    private fun isMarkdown(name: String, mimeType: String?): Boolean {
        val lowerName = name.lowercase()
        return lowerName.endsWith(".md") ||
            lowerName.endsWith(".markdown") ||
            mimeType == "text/markdown" ||
            mimeType == "text/x-markdown"
    }
}
