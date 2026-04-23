pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "OpenVibble"

include(
    ":app",
    ":buddy-protocol",
    ":nus-peripheral",
    ":buddy-storage",
    ":buddy-persona",
    ":buddy-stats",
    ":bridge-runtime",
    ":buddy-ui",
)
