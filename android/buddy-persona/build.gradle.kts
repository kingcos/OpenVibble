plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

java {
    toolchain { languageVersion.set(JavaLanguageVersion.of(17)) }
}

dependencies {
    implementation(project(":buddy-protocol"))
    implementation(libs.kotlinx.serialization.json)
    testImplementation(libs.junit)
}
