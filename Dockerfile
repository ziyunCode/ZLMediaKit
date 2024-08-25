ARG Version=7

FROM centos:${Version} As build

ARG HTTP_PROXY=${NO_PROXY}
ARG HTTPS_PROXY=${NO_PROXY}
ARG PKG_CONFIG_VERSION=0.29.2
ARG CMAKE_VERSION=3.18
ARG CMAKE_FULL_VERSION=3.18.4
ARG YASM_VERSION=1.3.0
ARG NASM_VERSION=2.15.05
ARG X265_VERSION=3.2
ARG OPENSSL_SERSION=1.1.1w
ARG LIBSRTP_VERSION=2.3.0

RUN rm -rf /etc/yum.repos.d/*

COPY /yum/* /etc/yum.repos.d/

RUN cat /etc/yum.repos.d/CentOS-Base.repo

RUN yum clean all && yum makecache

RUN yum install -y  \
        gcc \
        gcc-c++ \
        kernel-devel \
        kernel-headers \
        openssl \
        openssl-devel \
        git \
        wget \
        which 
    
WORKDIR /opt


RUN wget -e "https_proxy=" https://pkgconfig.freedesktop.org/releases/pkg-config-${PKG_CONFIG_VERSION}.tar.gz \
    && tar -zxvf pkg-config-${PKG_CONFIG_VERSION}.tar.gz \
    && cd pkg-config-${PKG_CONFIG_VERSION} \
    && ./configure --with-internal-glib \
    && make -j8 \
    && make install

RUN wget -e "https_proxy=" https://cmake.org/files/v${CMAKE_VERSION}/cmake-${CMAKE_FULL_VERSION}.tar.gz \
    && tar -zxvf cmake-${CMAKE_FULL_VERSION}.tar.gz \
    && cd cmake-${CMAKE_FULL_VERSION} \
    && ./bootstrap \
    && gmake -j8 \
    && gmake install 

RUN cd /opt \
    &&  wget -e "https_proxy=" http://www.tortall.net/projects/yasm/releases/yasm-${YASM_VERSION}.tar.gz \
    && tar zxvf yasm-${YASM_VERSION}.tar.gz \
    && cd yasm-${YASM_VERSION} \
    &&  ./configure \
    && make -j8 \
    && make install

RUN wget  -e "https_proxy=" https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.xz \
    && tar -xvJf nasm-${NASM_VERSION}.tar.xz \
    && cd nasm-${NASM_VERSION} \
    && ./configure --disable-shared --enable-static \
    && make -j8 \
    && make install

RUN cd /opt \
    && git clone https://code.videolan.org/videolan/x264.git \
    && cd x264 \
    && git checkout -b stable origin/stable \
    && git pull --rebase \
    && ./configure --enable-pic --enable-shared --disable-asm \
    && make -j8 \ 
    && make install \
    && export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

RUN cd /opt \
    && wget -e "https_proxy=" https://gh.con.sh/https://github.com/videolan/x265/archive/Release_${X265_VERSION}.tar.gz  \
    && tar zxvf Release_${X265_VERSION}.tar.gz \
    && cd x265-Release_${X265_VERSION}/build/linux \
    && cmake ../../source \
    && make -j8 \
    && make install \
    && export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH


RUN yum install -y \
		zlib \
        	zlib-devel \
        	perl-CPAN

RUN cd /opt \
    && wget -e "https_proxy="  https://mirror.ghproxy.com/https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-${OPENSSL_SERSION}.tar.gz \
    && tar zxvf openssl-${OPENSSL_SERSION}.tar.gz \
    && cd /opt/openssl-${OPENSSL_SERSION} \
    && ./config shared --openssldir=/usr/local/openssl --prefix=/usr/local/openssl \
    && make \
    && make install \
    && ln -s /usr/local/openssl/lib/libcrypto.so.1.1 /usr/lib64/libcrypto.so.1.1 \
    && ln -s /usr/local/openssl/lib/libssl.so.1.1 /usr/lib64/libssl.so.1.1 \       
    && mv /usr/bin/openssl /usr/bin/openssl1 \
    && ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl \
    && export PATH=/usr/local/openssl/bin:$PATH

RUN cd /opt \
    && wget -e "https_proxy=" https://cors.isteed.cc/https://github.com/cisco/libsrtp/archive/refs/tags/v${LIBSRTP_VERSION}.tar.gz \
    && tar zxvf v${LIBSRTP_VERSION}.tar.gz \
    && cd /opt/libsrtp-${LIBSRTP_VERSION} \
    && ./configure --enable-openssl --with-openssl-dir=/usr/local/openssl \
    && make \
    && make install 



RUN cd /opt \
    && git clone --depth 1 https://gitee.com/xia-chu/FFmpeg.git \
    && cd /opt/FFmpeg \
    && export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH \
    && ./configure \
        --disable-debug \
        --disable-doc  \
        --disable-shared  \
        --enable-gpl \
        --enable-version3 \
        --enable-static \
        --enable-nonfree \
        --enable-pthreads \
        --enable-libx264 \
        --enable-libx265 \
        --enable-small \
        --pkgconfigdir=/usr/local/lib/pkgconfig \
	    --pkg-config-flags="--static" \
    && make -j8 \
    && make install 

RUN cd /opt \
    && git clone --depth 1 https://githubfast.com/ziyunCode/ZLMediaKit.git AmCloudMedia \
    && cd AmCloudMedia \
    && git submodule update --init \
    && mkdir -p build release/linux/Release/ \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release .. -DENABLE_WEBRTC=true -DOPENSSL_ROOT_DIR=/usr/local/openssl  -DOPENSSL_LIBRARIES=/usr/local/openssl/lib \
    && make -j8


RUN mkdir -p /opt/build/opt/am/ /opt/build/usr/local/bin/ /opt/build/usr/bin/  /opt/build/usr/local/lib/ /opt/build/etc/localtime \
    && cd /opt/build \
    && /usr/bin/cp -ip /usr/local/lib/libx26* ./usr/local/lib \
    && /usr/bin/cp -ip /usr/local/bin/ffmpeg ./usr/local/bin \
    && /usr/bin/cp -frp /usr/local/openssl ./usr/local \
   # && /usr/bin/ln -s /usr/local/openssl/lib/libcrypto.so.1.1 ./usr/lib64/libcrypto.so.1.1 \
   # && /usr/bin/ln -s /usr/local/openssl/lib/libssl.so.1.1 ./usr/lib64/libssl.so.1.1 \
   # && /usr/bin/ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl \
    && /usr/bin/cp -ip /opt/AmCloudMedia/release/linux/Release/AmCloudServser ./opt/am/ \
    && /usr/bin/cp -irp /opt/AmCloudMedia/release/linux/Release/www ./opt/am/ \
    && /usr/bin/cp -ip /opt/AmCloudMedia/release/linux/Release/default.pem ./opt/am/ \
    && /usr/bin/cp -ip /usr/bin/which ./usr/bin/ 

FROM centos:${Version}
LABEL maintainer="amcloud <ziyun.blog@qq.com>" project-url="https://www.amingg.com"

EXPOSE 9000/tcp \
 1935/tcp \
 19350/tcp \
 554/tcp \
 322/tcp \
 80/tcp \
 443/tcp \
 10000/udp \
 10000/tcp \
 18080/tcp \
 10443/tcp \
 1599/tcp \
 8000/tcp 

WORKDIR /opt/am
VOLUME [ "/opt/am/conf/","/opt/am/log/","opt/am/ffmpeg/"]
COPY --from=build /opt/build /
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH TZ=Asia/Shanghai
CMD ["./AmCloudServser", "-c" , "./conf/config.ini"]

