# Деплой веб-сайта на VDS: Next.js, Docker, Django

Многие из вас, скорее всего, создавали веб-приложения. И вы хотели поделиться им - с другом, с заказчиком или просто похвастаться. Но вы стакливались с препятствием - чтобы поделиться, нужно опубликовать сайт в интернет. И тогда вы сталкиваетесь с тем, что процесс деплоя сайта выглядит пугающим. Docker, настройка сервера, DNS, CI/CD.

В этой статье я наглядно расскажу о том, **как настроить и запустить сайт на VDS сервере** через сервисы Timeweb Cloud. Чтобы установить веб-приложение на сервер, нужно будет создать Docker-контейнер настроить сам сервер для развертывания приложения.

В этом руководстве будет рассматриваться несколько технологий, и если вы столкнетесь с незнакомыми понятиями, не стоит волноваться. По мере прочтения у вас сложится пазл в голове, и в дальнейшем вы сможете сами **устанавливать сайт на VDS**. Итак, давайте рассмотрим публикацию поэтапно.

# План действий
В этой статье примером будет выступать полноценный веб-сайт - фронтенд на Next.js, бекенд на Django (python), контейнеризация через Docker, база данных sqlite3.

Мы также реализуем CI/CD для развертывания кода при коммите в основной ветке.

Для этого мы выполним следующие шаги:

 + Настроим фронтенд и бекенд части;
 + Настроим docker-контейнеры;
 + Настроим DNS домена.

# Необходимые требования
Начнем с главного:

1. Доменное имя - адрес вашего сайта в интернете;
2. Аккаунт в Timeweb Cloud - [зарегистрироваться можно по этой ссылке](https://timeweb.cloud/my/projects);
3. VDS - облачный сервер с IPv4, [создать можно по этой ссылке](https://timeweb.cloud/my/servers/create).

 > Я рекомендую прочитать данную статью полностью, перед тем как приступать к развертыванию. Это даст вам понять, что вас ждет и как лучше поступить в вашем конкретном случае.

# Покупка сервера

# Контейнеризация
Для этого туториала я создал репозиторий, который содержит два каталога: frontend и backend.

Директория frontend содержит код для Next.js-приложения, когда как backend отвечает за серверную часть (Django).

Чтобы начать, склонируете репозиторий:

```bash
git clone https://github.com/alexeeev-prog/website-deploy-tutorial-starter
```

И измените в `backend/backend/settings.py` константу ALLOWED_HOSTS:

```python
ALLOWED_HOSTS = [
	"109.68.212.254"
]
```

109.68.212.254 замените на IPv4 адрес сервера

## Создание докер-контейнера для фронтенда
В директории frontend есть файл Dockerfile, который отвечает за установку модулей и запуск приложения:

```Dockerfile
FROM node:20-alpine

WORKDIR /usr/app
COPY ./ /usr/app/

COPY package.json /usr/app/
RUN npm install --legacy-peer-deps
COPY . /usr/app

RUN npm run build

CMD ["npm", "run", "start"]
```

Он задействует NodeJS и пакетный менеджер npm для установки и запуска.

Также, есть файл `frontend/.dockerignore`, который копирует `frontend/.gitignore`.

## Создание докер-контейнера для бекенда
Теперь создадим контейнер для нашей серверной части на Django. Аналогично с фронтендом, есть Dockerfile, который выглядит следующим образом:

```Dockerfile
FROM python:3.9
ENV PYTHONBUFFERED 1

copy requirements.txt .
RUN python -m pip install -r requirements.txt

RUN mkdir app
WORKDIR /app
COPY . /app

CMD gunicorn --workers 3 -b 0.0.0.0:8000 config.wsgi
```

И абсолютно также существует файл `backend/.dockerignore`.

## Создание контейнера для nginx
Nginx - это веб сервер.

Существует файл nginx/nginx.conf:

```conf
events {
	worker_connections 1024;
}

http {
	server {
		listen 80;

		server_name tehnodrop.ru;

		location / {
			proxy_pass http://backend:8000;
			proxy_set_header Host $host;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_set_header x-Forwarded-Proto $scheme;
		}

		location /frontend/ {
			proxy_pass http://frontend:3000;
			proxy_set_header Host $host;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_set_header x-Forwarded-Proto $scheme;
		}
	}
}
```

И создадим Dockerfile:

```Dockerfile
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
```

## Создание docker-compose
Для того, чтобы наши докер контейнеры работали вместе, есть файл docker-compose.yml:

```yml
version: '3.8'

services:
    frontend:
        build:
            context: ./frontend
            dockerfile: Dockerfile
        ports:
             - "3000:3000"
        depends_on:
            - backend

    backend:
        build:
            context: ./backend
            dockerfile: Dockerfile
        ports:
            - "8000:8000"

    nginx:
        build:
            context: ./nginx
            dockerfile: Dockerfile
        ports:
            - "80:80"
        depends_on:
            - frontend
            - backend
```
