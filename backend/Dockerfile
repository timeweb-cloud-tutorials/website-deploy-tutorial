FROM python:3.9
ENV PYTHONBUFFERED 1

copy requirements.txt .
RUN python -m pip install -r requirements.txt

RUN mkdir app
WORKDIR /app
COPY . /app

CMD gunicorn --workers 3 -b 0.0.0.0:8000 config.wsgi
