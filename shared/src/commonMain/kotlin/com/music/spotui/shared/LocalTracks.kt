package com.music.spotui.shared

import com.metrolist.spotify.models.SpotifyTrack

/** Creates the same track model used by Android, without platform file APIs. */
object LocalTracks {
    fun fromFile(fileName: String, uri: String): SpotifyTrack = SpotifyTrack(
        id = uri,
        name = fileName.substringBeforeLast('.', fileName).ifBlank { fileName },
        isLocal = true,
        uri = uri,
    )
}
