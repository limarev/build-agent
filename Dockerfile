FROM ubuntu:22.04 as libreoffice_requirements

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# установка зависимостей
RUN apt-get update \
&& apt-get install -y \
--no-install-recommends \
--fix-missing \
git \
curl \
unzip \
cmake \
libssl-dev \
ca-certificates \
sudo \
build-essential \
gcc-12 \
g++-12 \
zip \
ccache \
junit4 \
libkrb5-dev \
nasm \
graphviz \
python3 \
python3-dev \
qtbase5-dev \
libkf5coreaddons-dev \
libkf5i18n-dev \
libkf5config-dev \
libkf5windowsystem-dev \
libkf5kio-dev \
autoconf \
libcups2-dev \
libfontconfig1-dev \
gperf \
default-jdk \
openjdk-17-jre \
doxygen \
libxslt1-dev \
xsltproc \
libxml2-utils \
libxrandr-dev \
libx11-dev \
bison \
flex \
libgtk-3-dev \
libgstreamer-plugins-base1.0-dev \
libgstreamer1.0-dev \
ant \
ant-optional \
libnss3-dev \
libavahi-client-dev \
libxt-dev \
autotools-dev \
automake \
gettext \
&& update-alternatives \
--install /usr/bin/gcc gcc /usr/bin/gcc-12 100 \
--slave /usr/bin/g++ g++ /usr/bin/g++-12 \
--slave /usr/bin/gcov gcov /usr/bin/gcov-12 \
&& apt-get upgrade -y \
&& rm -rf /var/lib/apt/lists/* \
&& apt clean autoclean && apt autoremove -y


FROM libreoffice_requirements as android_sdk

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# установка android command line tools и android sdk
ENV ANDROID_SDK_PATH=/opt/android_sdk
# нужен clang версии ниже 11.0 из-за https://github.com/llvm/llvm-project/issues/46483
# при сборке коллаборы требуется ndk 20.1.5948944: No version of NDK matched the requested version 20.1.5948944
ARG NDK_VERSION=20.1.5948944
ENV ANDROID_NDK_PATH=${ANDROID_SDK_PATH}/ndk/$NDK_VERSION
ARG cmdline_tools_path=$ANDROID_SDK_PATH/cmdline-tools/latest
ENV PATH="${PATH}:$cmdline_tools_path/bin"

ARG CLTOOLS_VERSION=10406996
RUN curl https://dl.google.com/android/repository/commandlinetools-linux-${CLTOOLS_VERSION}_latest.zip -o cmdtools.zip \
&& unzip cmdtools.zip \
&& rm cmdtools.zip \
&& mkdir -p $cmdline_tools_path \
&& mv /cmdline-tools/* $cmdline_tools_path \
&& yes | sdkmanager --licenses \
&& sdkmanager --install "ndk;$NDK_VERSION" "platform-tools" "platforms;android-21" "build-tools;34.0.0" "extras;google;m2repository" "extras;android;m2repository"


FROM android_sdk AS poco

ARG repo_name=poco
ARG source_dir=/tmp/${repo_name}
ARG install_dir=/opt/android-${repo_name}
ARG poco_version=1.12.4

COPY android-poco.patch /android-poco.patch

RUN mkdir -p ${source_dir} \
 && mkdir -p ${install_dir} \
 && curl -s -L https://github.com/pocoproject/poco/archive/refs/tags/poco-${poco_version}-release.tar.gz | tar xvzf - -C ${source_dir} --strip-components=1 \
 && cd ${source_dir} \
 && patch -p1 < /android-poco.patch \
 && export PATH="$PATH":${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin \
 && export SYSLIBS=-static-libstdc++ \
 && ./configure \
   --config=Android \
   --prefix=${install_dir} \
   --no-samples \
   --no-tests \
   --omit=ActiveRecord,Crypto,NetSSL_OpenSSL,Zip,Data,Data/SQLite,Data/ODBC,Data/MySQL,MongoDB,PDF,CppParser,PageCompiler,JWT,Prometheus,Redis \
 && make -sj12 ANDROID_ABI=armeabi-v7a CC=armv7a-linux-androideabi21-clang CXX=armv7a-linux-androideabi21-clang++ install \
 && make -sj12 ANDROID_ABI=arm64-v8a install \
 && make -sj12 ANDROID_ABI=x86       install \
 && make -sj12 ANDROID_ABI=x86_64    install


FROM android_sdk AS zstd

ARG repo_name=zstd
ARG source_dir=/tmp/${repo_name}
ARG build_dir=/tmp
ARG install_dir=/opt
ARG package=zstd

RUN mkdir -p ${source_dir} \
 && curl -s -L https://android.googlesource.com/platform/external/zstd/+archive/refs/heads/main.tar.gz | tar xvzf - -C ${source_dir} \
 && for p in armeabi-v7a arm64-v8a x86 x86_64; do \
        echo "Building $p:" \
        && mkdir -p $build_dir/$package/$p \
        && mkdir -p $install_dir/$package/$p \
        && cmake \
            -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_PATH/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$p \
            -DCMAKE_ANDROID_ARCH_ABI=$p \
            -DANDROID_NDK=$ANDROID_NDK_PATH \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_SYSTEM_NAME=Android \
            -DCMAKE_SYSTEM_VERSION=21 \
            -DZSTD_BUILD_PROGRAMS:BOOL=OFF \
            -DZSTD_BUILD_SHARED:BOOL=OFF \
            -DCMAKE_INSTALL_PREFIX=$install_dir/$package/$p \
            -S $source_dir/build/cmake \
            -B $build_dir/$package/$p \
        && cmake --build $build_dir/$package/$p --target install; \
  done


FROM android_sdk

COPY --from=poco /opt/android-poco /opt/android-poco
COPY --from=zstd /opt/zstd /opt/android-zstd

RUN apt-get update \
 && apt-get remove -y \
 openjdk-17-jre \
 openjdk-17-jre-headless \
 && apt-get install -y \
 libtool \
 python3-lxml \
 python3-polib \
 libcap-dev \
 npm \
 libpam-dev \
 libcap2-bin \
 libpng-dev \
 libcppunit-dev \
 pkg-config \
 fontconfig \
 snapd \
 gradle
#  openjdk-14-jre-headless
#  update-alternatives --config java
#  chromium-browser

# ENV JAVA_HOME=/usr/lib/jvm/java-14-openjdk-amd64

RUN addgroup --gid 1004 ghactions \
 && useradd --system --create-home --home-dir /home/ghactions --shell /bin/bash --gid 1004 --uid 1003 ghactions --password $(openssl passwd -1 ghactions)

WORKDIR /home/ghactions
COPY entrypoint.sh /home/ghactions
RUN chmod +x entrypoint.sh
RUN chown -R ghactions:ghactions $ANDROID_SDK_PATH

USER ghactions

ENTRYPOINT [ "/home/ghactions/entrypoint.sh" ]

# FROM ubuntu:22.04

# RUN apt-get update \
#  && apt-get install -y \
#  default-jdk
# RUN apt-get install -y gradle