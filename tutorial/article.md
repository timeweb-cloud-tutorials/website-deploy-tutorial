# Деплой веб-сайта на VDS: Next.js, Docker, Kubernetes, Django

Многие из вас, скорее всего, создавали веб-приложения. И вы хотели поделиться им - с другом, с заказчиком или просто похвастаться. Но вы стакливались с препятствием - чтобы поделиться, нужно опубликовать сайт в интернет. И тогда вы сталкиваетесь с тем, что процесс деплоя сайта выглядит пугающим. Docker, настройка сервера, DNS, CI/CD.

В этой статье я наглядно расскажу о том, **как настроить и запустить сайт на VDS сервере** через сервисы Timeweb Cloud. Чтобы установить веб-приложение на сервер, нужно будет создать Docker-контейнер, написать конфигурацию для Kubernetes, создать кластер Kubernetes, настроить сам сервер и настроить Github Actions для развертывания приложения.

В этом руководстве будет рассматриваться несколько технологий, и если вы столкнетесь с незнакомыми понятиями, не стоит волноваться. По мере прочтения у вас сложится пазл в голове, и в дальнейшем вы сможете сами **устанавливать сайт на VDS**. Итак, давайте рассмотрим публикацию поэтапно.

# План действий
В этой статье примером будет выступать полноценный веб-сайт - фронтенд на Next.js, бекенд на Django (python), контейнеризация через Docker, база данных sqlite3.

Мы также реализуем CI/CD для развертывания кода при коммите в основной ветке.

Для этого мы выполним следующие шаги:

 + Настроим фронтенд и бекенд части;
 + Напишем манифесты Kubernetes для серверной и клиентской частей, включая постоянный том для базы данных и получение SSL сертификата;
 + Настроим Кластер Kubernetes;
 + Настроим DNS домена;
 + Настроим GitHub Actions.

# Необходимые требования
Начнем с главного:

1. Доменное имя - адрес вашего сайта в интернете;
2. Аккаунт в Timeweb Cloud - [зарегистрироваться можно по этой ссылке](https://timeweb.cloud/my/projects);
3. VDS - облачный сервер, [создать можно по этой ссылке](https://timeweb.cloud/my/servers/create).

 > Я рекомендую прочитать данную статью полностью, перед тем как приступать к развертыванию. Это даст вам понять, что вас ждет и как лучше поступить в вашем конкретном случае.

# Контейнеризация
Для этого туториала я создал репозиторий, который содержит два каталога: frontend и backend.

Директория frontend содержит код для Next.js-приложения, когда как backend отвечает за серверную часть (Django).

Чтобы начать, склонируете репозиторий:

```bash
git clone https://github.com/alexeeev-prog/website-deploy-tutorial-starter
```

```
.
├── backend
│   ├── backend
│   │   ├── asgi.py
│   │   ├── __init__.py
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   ├── Dockerfile
│   ├── manage.py
│   └── requirements.txt
├── format-code.py
├── frontend
│   ├── Dockerfile
│   ├── package.json
│   ├── pages
│   │   └── index.js
│   ├── public
│   │   ├── favicon.ico
│   ├── README.md
│   └── styles
│       ├── globals.css
│       └── Home.module.css
```

## Создание докер-контейнера для фронтенда
В директории frontend есть файл Dockerfile, который отвечает за установку модулей и запуск приложения:

```Dockerfile
FROM node:16-alpine

COPY package.json .
RUN rm -rf node_modules/ .next/* && npm install --legacy-peer-deps
COPY ..

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

# Создание PVC для бекенда
Чтобы обеспечить сохранность файла базы данных SQLite, используемого в приложении Django, создадим заявку на PVC, создав файл pvc.yaml в k8s/volumes со следующим содержимым, которое выделяет 4 ГБ хранилища:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
	name: csi-pvc
spec:
	accessModes:
		 - ReadWriteOnce
	resources:
		requests:
			storage: 4Gi
	storageClassName: standard-rwo
```

 > PersistentVolumeClaim (PVC) в Kubernetes — это запрос на выделение хранилища от пользователя. Когда приложение в кластере нуждается в постоянном хранилище, оно не обращается напрямую к физическому ресурсу хранилища (PersistentVolume (PV)), а создаёт PVC, в котором описывает свои требования к нему. PVC обеспечивает изоляцию хранилища между различными приложениями и пользователями, позволяя каждому из них иметь свои собственные требования к хранилищу.

# Создание сервиса для бекенда и фронтенда
Чтобы наши серверные и клиентские части стали доступными в кластере, следует создать следующие файлы манифестов Kubernetes:

 > Kubernetes простыми словами можно описать как систему для автоматизации развёртывания, масштабирования и управления контейнерными приложениями. Она помогает упростить управление этими приложениями, управляя множеством маленьких коробок (контейнеров), чтобы всё работало гладко и без сбоев.

1. Развертывание сервера (k8s/app/backend-depl.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: backend-depl
spec:
	replicas: 1
	selector:
		matchLabels:
			app: backend
	template:
		metadata:
			labels:
				app: backend
		spec:
			volumes:
				- name: app-data
			persistentVolumeClaim:
				claimName: csi-pvc
			containers:
				- name: backend
			image: placeholder/backend:1.0.5
			volumeMounts:
				- mountPath: /app-data
				- name: app-data
---
apiVersion: v1
kind: Service
metadata:
	name: backend-srv
spec:
	selector:
		app: backend
	ports:
		- name: backend
		protocol: TCP
		port: 8000
		targetPort: 8000
```

2.  Развертывание фронтенда (k8s/app/frontend-depl.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: frontend-depl
spec:
	replicas: 1
	selector:
		matchLabels:
			app: frontend
	template:
		metadata:
			labels:
				app: frontend
		spec:
			containers:
				- name: frontend
				resources:
					requests:
						ephemeral-storage: "800Mi"
					limits:
						ephemeral-storage: "800Mi"
				image: placeholder/frontend:1.0.4
---
apiVersion: v1
kind: Service
metadata:
	name: frontend-srv
spec:
	selector:
		- name: frontend
		protocol: TCP
		port: 3000
		targetPort: 3000
```

# Балансировка нагрузки
Чтобы предоставить доступ к нашим модулям через сервисы, нам нужно создать ресурс Ingress. Создайте файл k8s/app/ingress.yaml (не забудьте заменить www.your-domain.com на свое доменное имя).

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-service
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: 80m
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
spec:
  rules:
    - host: "www.your-domain.com"
      http:
        paths:
          - path: /backend
            pathType: Prefix
            backend:
              service:
                name: backend-srv
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-srv
                port:
                  number: 3000

  tls:
    - hosts:
        - "www.your-domain.com"
      secretName: ssl-certificate

```

# Создание SSL-сертификата
Чтобы получить SSL-сертификат, мы снова воспользуемся k8s. Мы создадим файл k8s/certificates/certificates.yaml

 > SSL-сертификат — это цифровой сертификат, который удостоверяет подлинность веб-сайта и позволяет использовать зашифрованное соединение. 

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: youremail@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
        selector:
          dnsNames:
            - "www.your-domain.com"
```

# Github Actions
Чтобы автоматизировать процесс развертывания вашего приложения при каждом коммите в главную ветку, мы будем использовать GitHub Actions.

 > GitHub Actions — это платформа непрерывной интеграции и непрерывной поставки (CI/CD), которая позволяет автоматизировать конвейер сборки, тестирования и развёртывания.
