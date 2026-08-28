FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive STEAMCMDDIR=/opt/steamcmd SERVERDIR=/serverdata/serverfiles
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl wget bash procps lib32gcc-s1 lib32stdc++6 libx11-6:i386 libxext6:i386 libxdmcp6:i386 libgl1:i386 libglu1-mesa:i386 libxrandr2:i386 libxinerama1:i386 libxcursor1:i386 libxi6:i386 libfreetype6:i386 libgpg-error0:i386 && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 99 -U -s /bin/bash steam && mkdir -p /opt/steamcmd /serverdata/serverfiles && chown -R steam:steam /opt/steamcmd /serverdata
USER steam
WORKDIR /opt/steamcmd
RUN curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xzf -
COPY --chown=steam:steam defaults/ /opt/rwr-defaults/
COPY --chown=steam:steam start.sh /start.sh
COPY --chown=steam:steam start-options.sh /usr/local/lib/rwr/start-options.sh
COPY --chown=steam:steam install-utils.sh /usr/local/lib/rwr/install-utils.sh
COPY --chown=steam:steam runtime-utils.sh /usr/local/lib/rwr/runtime-utils.sh
COPY --chown=steam:steam rwr-unraid-persistent-invasion.as /usr/local/share/rwr/rwr-unraid-persistent-invasion.as
COPY --chown=steam:steam render-start-script.sh /usr/local/bin/rwr-render-start-script
COPY --chown=steam:steam render-admins.sh /usr/local/bin/rwr-render-admins
RUN chmod +x /start.sh /usr/local/bin/rwr-render-start-script /usr/local/bin/rwr-render-admins
WORKDIR /serverdata
EXPOSE 1240/tcp 1240/udp
ENTRYPOINT ["/start.sh"]
