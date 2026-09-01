FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# تثبيت متصفح Chromium، الشاشة، خادم الملفات noVNC ومكتبات النظام
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
    python3 \
    && rm -rf /var/lib/apt/lists/*

# تحميل نسخة noVNC الكلاسيكية ES5 المتوافقة مع iOS 9
RUN rm -rf /usr/share/novnc && \
    git clone --branch v0.6.2 --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc

# إنشاء مجلد التنزيلات المباشرة
RUN mkdir -p /root/Downloads /var/log/supervisor

# إعداد خادم الويب المزدوج (بث المتصفح + بوابة التحميل)
RUN echo '[supervisord]\nnodaemon=true\n\n\
[program:xvfb]\ncommand=Xvfb :0 -screen 0 1024x768x16\nautorestart=true\n\n\
[program:fluxbox]\ncommand=fluxbox\nenvironment=DISPLAY=":0"\nautorestart=true\n\n\
[program:x11vnc]\ncommand=x11vnc -display :0 -nopw -forever -shared -rfbport 5900\nautorestart=true\n\n\
[program:websockify]\ncommand=websockify --web /usr/share/novnc 10000 localhost:5900\nautorestart=true\n\n\
[program:file_server]\ncommand=python3 -m http.server 10001 --directory /root/Downloads\nautorestart=true\n\n\
[program:chromium]\ncommand=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --force-device-scale-factor=1.25 --window-size=1024,768 --start-maximized --default-search-provider-name="DuckDuckGo" https://duckduckgo.com\nenvironment=DISPLAY=":0"\nautorestart=true\n' > /etc/supervisor/conf.d/supervisord.conf

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
