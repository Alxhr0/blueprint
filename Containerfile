# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY brew/packages.Brewfile /usr/share/ublue-os/homebrew/packages.Brewfile


FROM ghcr.io/projectbluefin/bluefin-nvidia@sha256:e2c4c5643d96ad896076d10c660d239adddb8bfe650bc964b7b6f86b93fb2510

COPY --from=ghcr.io/ublue-os/brew:latest /system_files /

# RUN rm /opt && mkdir /opt
RUN mkdir -p /usr/share/ublue-os/homebrew/

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
RUN /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh