ARG AGENT_VERSION=3391.va_37fa_a_305d6d-5
FROM jenkins/inbound-agent:${AGENT_VERSION}-jdk21

USER root

ARG BETTERLEAKS_VERSION=1.9.0
ARG BETTERLEAKS_SHA256=f8b185a39ffcece2a1ca82bf3a4e7435cd81963ffd16b7a9128daf75f35f6de7

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/betterleaks.tgz \
        "https://github.com/betterleaks/betterleaks/releases/download/v${BETTERLEAKS_VERSION}/betterleaks_${BETTERLEAKS_VERSION}_linux_x64.tar.gz" \
    && echo "${BETTERLEAKS_SHA256}  /tmp/betterleaks.tgz" | sha256sum -c - \
    && tar -xzf /tmp/betterleaks.tgz -C /usr/local/bin betterleaks \
    && chmod +x /usr/local/bin/betterleaks \
    && rm /tmp/betterleaks.tgz

USER jenkins
