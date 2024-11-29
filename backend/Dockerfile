FROM python:3.9

copy requirements.txt .
RUN python -m pip install -r requirements.txt --no-cache-dir

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONBUFFERED 1

RUN mkdir app
WORKDIR /app
COPY . /app

EXPOSE 8000

CMD gunicorn --config=gunicorn_config.py backend.wsgi
