FROM nginx:alpine

COPY project /etc/nginx/sites-available/project
CMD ["ln", "-s", "/etc/nginx/sites-available/project", "/etc/nginx/sites-enabled"]
