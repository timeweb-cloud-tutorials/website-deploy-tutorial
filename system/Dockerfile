FROM alpine

COPY gunicorn.service /etc/systemd/system
COPY gunicorn.socket /etc/systemd/system

CMD ["systemctl", "enable", "gunicorn.socket", "&&", "systemctl", "start", "gunicorn.socket"]
