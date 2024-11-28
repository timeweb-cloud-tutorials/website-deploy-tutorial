FROM ubuntu:22.04

RUN apt-get update && apt-get install -y gunicorn systemd && apt-get clean

COPY gunicorn.service /etc/systemd/system
COPY gunicorn.socket /etc/systemd/system

RUN chmod +x ./entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

CMD ["systemctl", "enable", "gunicorn.socket", "&&", "systemctl", "start", "gunicorn.socket"]
