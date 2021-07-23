FROM ubuntu:20.04 as build-dep

# Use bash for the shell
SHELL ["/bin/bash", "-c"]

# Install build stage deps
RUN echo "Etc/UTC" > /etc/localtime && \
	apt-get update && \
	apt-get install -y --no-install-recommends \
	bison build-essential ca-certificates wget python git \
	libyaml-dev libgdbm-dev libreadline-dev libjemalloc-dev \
	libicu-dev libidn11-dev libpq-dev \
	libprotobuf-dev protobuf-compiler shared-mime-info \
	libncurses5-dev libffi-dev zlib1g-dev libssl-dev && \
	rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/ruby/bin:/opt/node/bin:/opt/mastodon/bin:${PATH}"

# Install Node v12 (LTS)
ENV NODE_VER="12.21.0"
RUN ARCH= && \
    dpkgArch="$(dpkg --print-architecture)" && \
  case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac && cd ~ && \
	wget -q https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER-linux-$ARCH.tar.gz && \
	tar xf node-v$NODE_VER-linux-$ARCH.tar.gz && \
	rm node-v$NODE_VER-linux-$ARCH.tar.gz && \
	mv node-v$NODE_VER-linux-$ARCH /opt/node

# Install Ruby
ENV RUBY_VER="2.7.4"
RUN cd ~ && \
	wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
	tar xf ruby-$RUBY_VER.tar.gz && \
	cd ruby-$RUBY_VER && \
	./configure --prefix=/opt/ruby \
	  --with-jemalloc \
	  --with-shared \
	  --disable-install-doc && \
	make -j"$(nproc)" > /dev/null && \
	make install && \
	rm -rf ../ruby-$RUBY_VER.tar.gz ../ruby-$RUBY_VER

RUN npm install -g yarn && \
	gem install bundler

COPY Gemfile* package.json yarn.lock /opt/mastodon/
RUN cd /opt/mastodon && \
	bundle config set deployment 'true' && \
	bundle config set without 'development test' && \
	bundle install -j"$(nproc)" && \
	yarn install --pure-lockfile

COPY . /opt/mastodon/
RUN cd /opt/mastodon && \
	RAILS_ENV=production OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder \
		rails assets:precompile && \
	yarn cache clean && \
	rm -rf tmp

# Build runtime stage
FROM ubuntu:20.04

# Add more PATHs to the PATH
ENV PATH="/opt/ruby/bin:/opt/node/bin:/opt/mastodon/bin:${PATH}"

# Use bash for the shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup mastodon runtime deps & configs
ARG UID=991
ARG GID=991
RUN echo "Etc/UTC" > /etc/localtime && \
	apt-get update && \
	apt-get install -y --no-install-recommends whois wget \
	  libssl1.1 libpq5 imagemagick ffmpeg libjemalloc2 \
	  libicu66 libprotobuf17 libidn11 libyaml-0-2 \
	  file ca-certificates tzdata libreadline8 tini && \
	addgroup --gid $GID mastodon && \
	useradd -m -u $UID -g $GID -d /opt/mastodon mastodon && \
	ln -s /opt/mastodon /mastodon && \
	echo "mastodon:$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256)" | chpasswd && \
	rm -rf /var/cache && \
	rm -rf /var/lib/apt/lists/*

# Copy over all the langs needed for runtime
COPY --from=build-dep /opt/node /opt/node
COPY --from=build-dep /opt/ruby /opt/ruby
# Copy over mastodon source, and dependencies from building, and set permissions
COPY --from=build-dep --chown=mastodon:mastodon /opt/mastodon /opt/mastodon

# Run mastodon services in prod mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"
ENV BIND="0.0.0.0"

# Set the run user
USER mastodon

# Set the work dir and the container entry point
WORKDIR /opt/mastodon
ENTRYPOINT ["/usr/bin/tini", "--"]
EXPOSE 3000 4000
