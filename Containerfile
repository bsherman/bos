ARG BASE_REF="ucore-minimal:stable@sha256:c3c7cc790b4f9aa80a78f99487a63b576b77824eb94947ed27814d82e367855f"
ARG IMAGE="bluefin"

FROM scratch AS ctx
COPY / /

FROM ghcr.io/ublue-os/${BASE_REF}

ARG BASE_IMAGE="bluefin"
ARG DNF=""
ARG IMAGE="bluefin"
ARG SET_X=""
ARG VERSION=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/build.sh
