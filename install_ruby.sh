#!/bin/bash

set -ex

RUBY_VERSION=${RUBY_VERSION-2.5.3}
RUBY_MAJOR=$(echo -n $RUBY_VERSION | sed -E 's/\.[0-9]+(-.*)?$//g')
RUBYGEMS_VERSION=${RUBYGEMS_VERSION-2.7.8}
BUNDLER_VERSION=${BUNDLER_VERSION-1.17.1}

case $RUBY_VERSION in
  trunk:*)
    RUBY_TRUNK_COMMIT=$(echo $RUBY_VERSION | awk -F: '{print $2}' )
    RUBY_VERSION=trunk
    ;;
  2.6.0-rc1)
    RUBY_DOWNLOAD_SHA256=21d9d54c20e45ccacecf8bea4dfccd05edc52479c776381ae98ef6a7b4afa739
    ;;
  2.5.3)
    RUBY_DOWNLOAD_SHA256=1cc9d0359a8ea35fc6111ec830d12e60168f3b9b305a3c2578357d360fcf306f
    ;;
  2.4.5)
    RUBY_DOWNLOAD_SHA256=2f0cdcce9989f63ef7c2939bdb17b1ef244c4f384d85b8531d60e73d8cc31eeb
    ;;
  2.3.8)
    RUBY_DOWNLOAD_SHA256=910f635d84fd0d81ac9bdee0731279e6026cb4cd1315bbbb5dfb22e09c5c1dfe
    ;;
  *)
    echo "Unsupported RUBY_VERSION ($RUBY_VERSION)" >2
    exit 1
    ;;
esac

case $RUBY_VERSION in
  2.3.*)
    # Need to down grade openssl to 1.0.x for Ruby 2.3.x
    apt-get install -y --no-install-recommends libssl1.0-dev
    ;;
esac

if test -n "$RUBY_TRUNK_COMMIT"; then
  if test -f /usr/src/ruby/configure.ac; then
    cd /usr/src/ruby
    git pull --rebase origin
  else
    rm -r /usr/src/ruby
    git clone https://github.com/ruby/ruby.git /usr/src/ruby
    cd /usr/src/ruby
  fi
  git checkout $RUBY_TRUNK_COMMIT
else
  wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/ruby-${RUBY_VERSION}.tar.xz"
  echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c -
  mkdir -p /usr/src/ruby
  tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1
  rm ruby.tar.xz
fi

(
  cd /usr/src/ruby
  autoconf

  mkdir -p /tmp/ruby-build
  pushd /tmp/ruby-build

  gnuArch=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)
  /usr/src/ruby/configure \
    --build="$gnuArch" \
    --prefix=/usr/local \
    --disable-install-doc \
    --enable-shared \
    optflags="-O3 -mtune=native -march=native" \
    debugflags="-g"

  make -j "$(nproc)"
  make install

  popd
  rm -rf /tmp/ruby-build
)

if test $RUBY_VERSION != "trunk"; then
  gem update --system "$RUBYGEMS_VERSION"
fi

gem install bundler --version "$BUNDLER_VERSION" --force

rm -r /usr/src/ruby /root/.gem/
