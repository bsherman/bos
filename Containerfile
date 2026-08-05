ARG BASE_REF="ucore-minimal:stable"
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
