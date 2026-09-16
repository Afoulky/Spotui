package com.music.spotui.shared

import com.metrolist.spotify.models.SpotifyTrack
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TrackCompatibilityTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun spotifyPayloadKeepsAndroidFieldNamesAndDefaults() {
        val track = json.decodeFromString<SpotifyTrack>(
            """{"id":"track-id","name":"Song","duration_ms":123000,
                "artists":[{"name":"Artist"}],"external_ids":{"isrc":"ABC123"},
                "unknown_future_field":true}"""
        )
        assertEquals(123000, track.durationMs)
        assertEquals("Artist", track.artists.single().name)
        assertEquals("ABC123", track.isrc)
        assertFalse(track.isLocal)
        assertEquals(track, json.decodeFromString<SpotifyTrack>(json.encodeToString(track)))
    }

    @Test
    fun localTrackRetainsItsFileIdentity() {
        val uri = "file:///Documents/Music/123/My.song.m4a"
        val track = LocalTracks.fromFile("My.song.m4a", uri)
        assertEquals("My.song", track.name)
        assertEquals(uri, track.id)
        assertEquals(uri, track.uri)
        assertTrue(track.isLocal)
    }

    @Test
    fun extensionlessAndHiddenFilesStillHaveNames() {
        assertEquals("Recording", LocalTracks.fromFile("Recording", "file:///a").name)
        assertEquals(".audio", LocalTracks.fromFile(".audio", "file:///b").name)
    }
}
