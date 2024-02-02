#!/bin/bash

set -x

function build_collabora {

poco=/opt/android-poco
zstd=/opt/android-zstd

# https://stackoverflow.com/questions/61289461/java-lang-noclassdeffounderror-could-not-initialize-class-org-codehaus-groovy-v
# sed -i 's/gradle-5\.6\.4-all\.zip/gradle-6\.7\.1-all\.zip/g' android/gradle/wrapper/gradle-wrapper.properties
# cat android/gradle/wrapper/gradle-wrapper.properties

# https://stackoverflow.com/questions/67782975/how-to-fix-the-module-java-base-does-not-opens-java-io-to-unnamed-module
# sed -i 's/com\.android\.tools\.build:gradle:3\.6\.4/com\.android\.tools\.build:gradle:4\.2\.0/g' android/build.gradle
# cat android/build.gradle
# gradle -q version
export ANDROID_SDK_ROOT=${ANDROID_SDK_PATH}
./autogen.sh
./configure --enable-androidapp \
            --with-lo-builddir=$workspace/github_android_armeabi-v7a_core_co-23.05:$workspace/github_android_arm64-v8a_core_co-23.05:$workspace/github_android_x86_core_co-23.05:$workspace/github_android_x86-64_core_co-23.05 \
            --with-poco-includes=$poco/include:$poco/include:$poco/include:$poco/include \
            --with-poco-libs=$poco/armeabi-v7a/lib:$poco/arm64-v8a/lib:$poco/x86/lib:$poco/x86_64/lib \
            --with-zstd-includes=$zstd/armeabi-v7a/include:$zstd/arm64-v8a/include:$zstd/x86/include:$zstd/x86_64/include \
            --with-zstd-libs=$zstd/armeabi-v7a/lib:$zstd/arm64-v8a/lib:$zstd/x86/lib:$zstd/x86_64/lib \
            --disable-setcap \
            --enable-silent-rules
            # --enable-debug
make
cd android
./gradlew --parallel build

}

function generate_autogen {
    echo \
    "--with-android-package-name=com.collabora.for.gerrit
    --with-android-ndk=${ANDROID_NDK_PATH}
    --with-android-sdk=${ANDROID_SDK_PATH}
    --with-distro=$1
    --with-lang=ca ru
    --disable-ccache" > autogen.input
}

function build {
    generate_autogen $1
    make distclean
    ./autogen.sh && make
}

case $1 in
    "fetch")
        generate_autogen CPAndroid
        make distclean
        ./autogen.sh && make fetch
        ;;
    "armeabi-v7a")
        build "CPAndroid"
        ;;
    "arm64-v8a")
        build "CPAndroidAarch64"
        ;;
    "x86")
        build "CPAndroidX86"
        ;;
    "x86_64")
        build "CPAndroidX86_64"
        ;;
    "Collabora")
        build_collabora
        ;;
    *)
        echo "Available options: fetch armeabi-v7a arm64-v8a x86 x86_64 Collabora. Run /bin/bash ..."
        /bin/bash
esac
