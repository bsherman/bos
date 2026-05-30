# bOS

[![bOS Build Desktop](https://github.com/bsherman/bos/actions/workflows/build-desktop.yml/badge.svg)](https://github.com/bsherman/bos/actions/workflows/build-desktop.yml)
[![bOS Build Server](https://github.com/bsherman/bos/actions/workflows/build-server.yml/badge.svg)](https://github.com/bsherman/bos/actions/workflows/build-server.yml)

These are my personal Universal Blue image builds, customized with a few extras to make life good on my family's laptops and home servers.

The name is intentionally ambiguous and fun.  Is it "boss", or "bee-O-S", or "bee-aws"?


## Under the Hood

There's a single image name `bos` with multiple tags. The idea is, *I run **bOS** for all my use cases.*


### Desktops

Desktop(and laptop) images are built upon [Bazzite](https://github.com/ublue-os/bazzite).

**KDE variants** (default Bazzite desktop):

- `bos:bazzite` - a Bazzite (KDE)
- `bos:bazzite-nvidia` - a Bazzite image with Nvidia support (KDE)

**GNOME variants**:

- `bos:bazzite-gnome` - a Bazzite (GNOME)
- `bos:bazzite-gnome-nvidia` - a Bazzite image with Nvidia support (GNOME)

### Servers

Server images are built upon [uCore](https://github.com/ublue-os/ucore).

- `bos:ucore` - a uCore stable image with ZFS support
- `bos:ucore-nvidia` - a uCore stable image with ZFS and Nvidia support
- `bos:ucore-hci` - a uCore HCI stable image with ZFS support (adds hypervisor to uCore)
- `bos:ucore-hci-nvidia` - a uCore HCI stable image with ZFS and Nvidia support (adds hypervisor to uCore)
- `bos:ucore-minimal` - a uCore minimal stable image (*without* ZFS or Nvidia support)

## How to Install

Use the installation method for the respective upstream, Bazzite, uCore, etc.

Then switch to **bOS** with a command like:

```
sudo bootc switch --enforce-container-sigpolicy ghcr.io/bsherman/bos:TAG
```

## Verification

These images are signed with sigstore's [cosign](https://docs.sigstore.dev/cosign/overview/) using. You can verify the signature by running the following command:

```
cosign verify --key cosign.pub ghcr.io/bsherman/bos:TAG
```

## DIY

This repo was built on the [Universal Blue Image Template](https://github.com/ublue-os/image-template) though it's been added to significantly.

That template can be used to extend any image you like, Aurora, Bazzite, Bazzite, uCore or even **bOS** so you can make your own ***bOS***!

Also, if you just want to tinker, the images built here can be built locally using [`just`](https://just.systems/) and the provided `Justfile`.

```
# example
just build bazzite
```

## Development Structure

The build system is intentionally straightforward:

- `build.sh` — Main build entrypoint (executed inside the container during the build)
- `build_scripts/` — Individual scripts for package installation, configuration changes, signing, cleanup, and helpers
- `system_files/` — Overlay files and configs merged into the image (shared + desktop/server specific)
- `Justfile` — Local development commands (`just build`, `just lint`, `just format`, etc.).
  Image variants and build metadata are defined in `images.yaml`.
- `Containerfile` — Minimal definition that copies everything and invokes `build.sh`
