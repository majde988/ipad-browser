FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# تثبيت الأدوات ومتصفح Chromium مع git
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    chromium \
    supervisor \
    procps \
    git \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# تحميل نسخة noVNC الكلاسيكية (v0.6.2) المكتوبة بـ ES5 خصيصاً لـ iOS 9
RUN rm -rf /usr/share/novnc && \
    git clone --branch v0.6.2 --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc

# إعداد السيرفور وبث الويب
RUN echo '[supervisord]\nnodaemon=true\n\n\
[program:xvfb]\ncommand=Xvfb :0 -screen 0 1024x768x16\nautorestart=true\n\n\
[program:fluxbox]\ncommand=fluxbox\nenvironment=DISPLAY=":0"\nautorestart=true\n\n\
[program:x11vnc]\ncommand=x11vnc -display :0 -nopw -forever -shared -rfbport 5900\nautorestart=true\n\n\
[program:websockify]\ncommand=websockify --web /usr/share/novnc 10000 localhost:5900\nautorestart=true\n\n\
[program:chromium]\ncommand=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --window-size=1024,768 --start-maximized https://google.com\nenvironment=DISPLAY=":0"\nautorestart=true\n' > /etc/supervisor/conf.d/supervisord.conf

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
