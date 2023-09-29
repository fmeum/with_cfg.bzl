load("@rules_java//toolchains:remote_java_repository.bzl", "remote_java_repository")

def _remotejdk21_repos_impl(_):
    """Imports OpenJDK 21 repositories."""
    remote_java_repository(
        name = "remotejdk21_linux",
        target_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
        sha256 = "0c0eadfbdc47a7ca64aeab51b9c061f71b6e4d25d2d87674512e9b6387e9e3a6",
        strip_prefix = "zulu21.28.85-ca-jdk21.0.0-linux_x64",
        urls = [
            "https://cdn.azul.com/zulu/bin/zulu21.28.85-ca-jdk21.0.0-linux_x64.tar.gz",
        ],
        version = "21",
    )

    remote_java_repository(
        name = "remotejdk21_macos",
        target_compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
        sha256 = "9639b87db586d0c89f7a9892ae47f421e442c64b97baebdff31788fbe23265bd",
        strip_prefix = "zulu21.28.85-ca-jdk21.0.0-macosx_x64",
        urls = [
            "https://cdn.azul.com/zulu/bin/zulu21.28.85-ca-jdk21.0.0-macosx_x64.tar.gz",
        ],
        version = "21",
    )

    remote_java_repository(
        name = "remotejdk21_win",
        target_compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
        sha256 = "e9959d500a0d9a7694ac243baf657761479da132f0f94720cbffd092150bd802",
        strip_prefix = "zulu21.28.85-ca-jdk21.0.0-win_x64",
        urls = [
            "https://cdn.azul.com/zulu/bin/zulu21.28.85-ca-jdk21.0.0-win_x64.zip",
        ],
        version = "21",
    )

remotejdk21_repos = module_extension(_remotejdk21_repos_impl)
