# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY brew/packages.Brewfile /usr/share/ublue-os/homebrew/packages.Brewfile


FROM ghcr.io/ublue-os/aurora-nvidia-open:stable

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