FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# تثبيت الأدوات ومتصفح Chromium مع أداة البث noVNC
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    novnc \
    websockify \
    chromium \
    supervisor \
    procps \
    && rm -rf /var/lib/apt/lists/*

# إعداد السيرفور والشاشة وبث الويب على المنفذ 10000 الخاص بـ Render
RUN echo '[supervisord]\nnodaemon=true\n\n\
[program:xvfb]\ncommand=Xvfb :0 -screen 0 1024x768x16\nautorestart=true\n\n\
[program:fluxbox]\ncommand=fluxbox\nenvironment=DISPLAY=":0"\nautorestart=true\n\n\
[program:x11vnc]\ncommand=x11vnc -display :0 -nopw -forever -shared -rfbport 5900\nautorestart=true\n\n\
[program:websockify]\ncommand=websockify --web /usr/share/novnc 10000 localhost:5900\nautorestart=true\n\n\
[program:chromium]\ncommand=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --window-size=1024,768 --start-maximized https://google.com\nenvironment=DISPLAY=":0"\nautorestart=true\n' > /etc/supervisor/conf.d/supervisord.conf

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
