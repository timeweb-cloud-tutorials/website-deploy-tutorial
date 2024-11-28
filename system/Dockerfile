FROM ubuntu:20.04

RUN apt-get update && apt-get install -y gunicorn systemd && apt-get clean

WORKDIR /app
COPY . .

COPY gunicorn.service /etc/systemd/system
COPY gunicorn.socket /etc/systemd/system

RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["systemctl", "enable", "gunicorn.socket", "&&", "systemctl", "start", "gunicorn.socket"]
