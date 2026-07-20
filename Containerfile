ARG BASE_IMAGE="bluefin"
ARG BASE_TAG="stable-daily@sha256:2d7b7ea13d91092f6bdb7b710b2baba649c2c577c668e3df1635ed6e52a18a03"
ARG IMAGE="bluefin"

FROM scratch AS ctx
COPY / /

FROM ghcr.io/ublue-os/${BASE_IMAGE}:${BASE_TAG}

ARG BASE_IMAGE="bluefin"
ARG DNF=""
ARG IMAGE="bluefin"
ARG SET_X=""
ARG VERSION=""

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=secret,id=GITHUB_TOKEN \
    /ctx/build.sh
