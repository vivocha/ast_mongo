ARG VERSION_UBUNTU=latest
FROM ubuntu:$VERSION_UBUNTU
MAINTAINER KINOSHITA minoru <5021543+minoruta@users.noreply.github.com>

#
#   Essential arguments
#
ARG VERSION_ASTERISK=16.0.0
ARG VERSION_MONGOC=1.13.0

ENV HOME /root
WORKDIR $HOME

RUN apt -qq update \
&&  apt -qq install -y \
    curl build-essential pkg-config bzip2 patch cmake autoconf file git \
    libedit-dev libjansson-dev libsqlite3-dev uuid-dev libxml2-dev \
    libspeex-dev libspeexdsp-dev libogg-dev libvorbis-dev libasound2-dev portaudio19-dev libcurl4-openssl-dev \
    libpq-dev unixodbc-dev libgmime-2.6-dev liblua5.2-dev liburiparser-dev libxslt1-dev libssl-dev \
    libmysqlclient-dev libosptk-dev libjack-jackd2-dev libcfg-dev libspandsp-dev \
    libresample1-dev binutils-dev libsrtp0-dev libsrtp2-dev libgsm1-dev zlib1g-dev libldap2-dev \
    libcodec2-dev libfftw3-dev libsndfile1-dev libunbound-dev libsasl2-dev libncurses5-dev

#
#   Prepare MongoDB C Driver
#
RUN curl -L "https://github.com/mongodb/mongo-c-driver/releases/download/$VERSION_MONGOC/mongo-c-driver-$VERSION_MONGOC.tar.gz" | tar xzf - \
&&  cd $HOME/mongo-c-driver-$VERSION_MONGOC \
&&  mkdir cmake-build \
&&  cd cmake-build \
&&  cmake -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF .. \
&&  make \
&&  make install \
&&  cd $HOME \
&&  rm -rf mongo-c-driver-$VERSION_MONGOC.tar.gz mongo-c-driver-$VERSION_MONGOC

#
#   Build and install Asterisk with patches for ast_mongo
#
RUN curl -L "http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-$VERSION_ASTERISK.tar.gz" | tar xzf -
COPY src/cdr_mongodb.c $HOME/asterisk-$VERSION_ASTERISK/cdr/
COPY src/cel_mongodb.c $HOME/asterisk-$VERSION_ASTERISK/cel/
COPY src/res_mongodb.c $HOME/asterisk-$VERSION_ASTERISK/res/
COPY src/res_mongodb.exports.in $HOME/asterisk-$VERSION_ASTERISK/res/
COPY src/res_config_mongodb.c $HOME/asterisk-$VERSION_ASTERISK/res/
COPY src/res_mongodb.h $HOME/asterisk-$VERSION_ASTERISK/include/asterisk/
COPY src/mongodb.for.asterisk.patch $HOME/asterisk-$VERSION_ASTERISK/

RUN cd $HOME/asterisk-$VERSION_ASTERISK \
&&  patch -p1 -F3 -i ./mongodb.for.asterisk.patch \
&&  ./bootstrap.sh \
&&  ./configure --disable-xmldoc --with-pjproject-bundled \
&&  make menuselect.makeopts \
&&  menuselect/menuselect --disable CORE-SOUNDS-EN-GSM --enable CORE-SOUNDS-EN-ULAW --enable CORE-SOUNDS-IT-ULAW --disable BUILD_NATIVE --disable chan_sip menuselect.makeopts \
&&  make all \
&&  make install \
&&  ldconfig /usr/lib \
&&  make samples \
&&  cd $HOME \
&&  rm -rf asterisk-$VERSION_ASTERISK.tar.gz asterisk-$VERSION_ASTERISK

#
# Launch asterisk
#
CMD asterisk -c > /dev/null
