pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
    }
}

rootProject.name = "spotui"
include(":spotify")
include(":shared")
// iOS and shared-code checks do not require an Android SDK.
if (!providers.gradleProperty("sharedOnly").orNull.toBoolean()) {
    include(":app")
    include(":innertube")
}
