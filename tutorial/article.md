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

# Необходимые требования
Начнем с главного:

1. Аккаунт в Timeweb Cloud - [зарегистрироваться можно по этой ссылке](https://timeweb.cloud/my/projects);
2. VDS - облачный сервер с IPv4, [создать можно по этой ссылке](https://timeweb.cloud/my/servers/create);
3. Доменное имя.

 > Я рекомендую прочитать данную статью полностью, перед тем как приступать к развертыванию. Это даст вам понять, что вас ждет и как лучше поступить в вашем конкретном случае.

# Настройка сервера
Купить сервер можно по [этой ссылке](https://timeweb.cloud/my/servers/create).

Внизу вы видите самый дешевый комплект - 285 рублей в месяц за стандартный VDS с публичным IPv4. ОС будет Ubuntu 22.04, все команды будут именно для нее.

![](https://habrastorage.org/webt/hp/iu/gf/hpiugfm3fssojfdygp_rxs7gt94.png)

После вам нужно будет подключиться по SSH.

Если у вас Linux, то вы можете просто ввести команду:

```bash
ssh root@<ip>
```

Как вы видите, по умолчанию мы подключаемся к root. Это является брешью в безопасности, позднее мы ее исправим.

А для Windows вы можете установить [PuTTY](https://www.putty.org/) — клиент SSH.

## Установка софта
Нам нужно будет установить:

1. Docker - это платформа контейнеризации, с помощью которой можно автоматизировать и отделить приложения от основной системы. 
2. Docker-compose - это надстройка над докером, которая позволяет запускать несколько контейнеров одновременно и маршрутизировать потоки данных между ними.

```bash
sudo snap install docker
```

## Настройка безопасности
Итак, вы решили **опубликовать сайт на VDS сервере**. Это происходит публично, поэтому стоит подумать о том, как защитить свой сервер.

### Новый пользователь
Как я говорил выше, одна из проблем - то что через ssh мы сразу подключаемся к руту, то есть удаленно администрируем сервер без ограничений. А этим может воспользоваться злоумышленник.

Поэтому мы заведем другого пользователя и отключим доступ к ssh через рут.

Для этого существует команда useradd:

```
useradd [options] <username>
```

После нужно задать пароль новому пользователю и добавить его в группу sudo:

```
passwd <username>
usermod -aG sudo <username>
```

Группа sudo нужна для того, чтобы мы могли работать с рутом.

## Аутентификация через ключ
Чтобы мы могли подключаться к серверу через ssl-ключ, а не через пароли, нам нужно его сгенерировать. Иначе останется возможность утечки пароля администратора:

```bash
ssh-keygen -t rsa
```

Затем скопируйте публичный ключ (`~/.ssh/id_rsa.pub`) и вставьте его в секцию SSH-ключей сервера на Timeweb Cloud.

![](https://habrastorage.org/webt/_y/0m/cp/_y0mcpwxpp5eshft35tj2kfj47y.png)

Также давайте настроим SSH-ключ для пользователя.

Есть разные программы для реализации протокола SSH, такие как lsh и Dropbear, но самой популярной является OpenSSH. Установка клиента OpenSSH на Ubuntu:

```bash
sudo apt install openssh-client
```

Установка на сервере:

```bash
sudo apt install openssh-server
```

Запуск демона SSH (sshd) на сервере под Ubuntu:

```bash
sudo systemctl start ssh
sudo systemctl enable ssh
```

После вы должны создать на сервере директорию SSH в домашней директории юзера (будучи из-под рута) и добавить публичный ключ, который мы сгенерировали ранее, в файл authorized_keys. А также изменить права:

```bash
mkdir -p /home/<username>/.ssh && touch /home/<username>/.ssh/authorized_keys
chmod 700 /home/<username>/.ssh && chmod 600 /home/<username>/.ssh/authorized_keys
chown -R <username>:<username> /home/<username>/.ssh
```

После отредактируем файл /etc/ssh/sshd_config:

```bash
PermitRootLogin no # изменить с yes на no
PasswordAuthentication no # изменить с yes на no
```

Эти параметры запретят входить через рута и аутентификацию по паролю.

## Настройка файрволла
Файрволл, грубо говоря, блокирует часть портов для защиты от посторонних подключений. В Ubuntu идет встроенный ufw, поэтому настроим его:

```bash
sudo ufw allow ssh # разрешаем ssh
sudo ufw enable # запускаем
```

## Fail2Ban
[Fail2Ban](https://www.fail2ban.org/wiki/index.php/Main_Page) - это утилита для защиты от брутфорса. Она анализирует логи и попытки входа, и может блокировать IP адреса в зависимости от правил. Например, после 5 неудачных попыток в течении 10 минут, блокируем IP адрес на 2 часа.

```bash
sudo apt install fail2ban
systemctl start fail2ban
systemctl enable fail2ban
```

И редактируем конфиг /etc/fail2ban/jail.conf:

```
[DEFAULT]
ignorecommand =
bantime = 120m
findtime = 10m
maxretry = 9
```

Если в течении 10 минут было 9 попыток войти, мы блокируем IP на 120 минут.

Поэтому в /etc/ssh/sshd_config поменяйте следующее значение:

```bash
Port 9009 # поменяйте с 22 на любой незанятый и незаблокированный 
```

## Смена порта SSH
Злоумышленник изначально будет пробовать 22 порт - порт сервиса ssh по умолчанию. Чтобы не допустить взлома, надо сменить его.

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
	"109.68.212.254", 'tehnodrop.ru', 'localhost', '0.0.0.0'
]
```

109.68.212.254 замените на IPv4 адрес сервера, tehnodrop.ru на ваш домен.

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

CMD gunicorn --workers 3 -b 0.0.0.0:8000 backend.wsgi
```

И абсолютно также существует файл `backend/.dockerignore`.

Теперь время создать сокет и сервис для gunicorn:

```bash
sudo nano /etc/systemd/system/gunicorn.socket
```

```
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
```

```bash
sudo nano /etc/systemd/system/gunicorn.service
```

```
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target
[Service]
# имя вашего пользователя
User=user 
#путь до каталога с файлом manage.py
WorkingDirectory=/home/user/website-deploy-tutorial/backend
ExecStart=gunicorn --workers 3 -b 0.0.0.0:8000 backend.wsgi --bind unix:/run/gunicorn.sock
#путь до файла gunicorn в виртуальном окружении (также не забудьте указать верный путь до файла wsgi (обычно лежит рядом с settings.py))
[Install]
WantedBy=multi-user.target
```

И запускаем их:

```bash
sudo systemctl start gunicorn.socket
sudo systemctl enable gunicorn.socket
```

Если что-то пошло не так - в первую очередь проверяем логи:

```bash
sudo journalctl -u gunicorn.socket
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
```

# Запуск
После того, как вы все настроили, перейдите директорию с файлом docker-compose.yml и запустите следующую команду:

```bash
sudo docker-compose up --build -d
```

Эта команда соберет все контейнеры и запустит их в режими демона. Поздравляю! Вы прошли туториал **как поставить сайт на VDS**!
