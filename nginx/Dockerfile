FROM nginx:1.23-alpine

RUN rm /etc/nginx/sites-enabled/default
RUN rm /etc/nginx/sites-available/default
COPY nginx.conf /etc/nginx/sites-available/default
RUN ln s /etc/nginx/sites-available/default /etc/nginx/sites-enabled
