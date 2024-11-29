sudo cp default -r /etc/nginx/sites-available/
sudo rm -rf /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled
sudo nginx -t
sudo nginx -s
sudo systemctl restart nginx
