# Multi-site docker-compose with proxy and SSL

This docker-compose stack allows to have in a centralized and very simple way, multiple websites hosted, with SSL, and with a reverse proxy through nginx

## Table of contents

## Prerequisites
1. [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/) are installed
2. You have a registered domain name
3. You have a server with a publicly routable IP address
4. You have cloned this repository:
   ```bash
   git clone https://github.com/rdiezsj/multisite-with-proxy-and-SSL-docker.git
   ```

### Create DNS records

For all domain names create DNS A records to point to a server where Docker containers will be running.
Also, consider creating CNAME records for the `www` subdomains.

If you are using a DDNS service, make sure the records point to the correct IP

**DNS records**

| Type  | Hostname             | Value                           |
|-------|----------------------|---------------------------------|
| A     | `test1.fake.com`     | directs to IP address `X.X.X.X` |
| A     | `test2.foo.com`      | directs to IP address `X.X.X.X` |
| CNAME | `www.test1.fake.com` | is an alias of `test1.fake.com` |
| CNAME | `www.test2.foo.com`  | is an alias of `test2.foo.com`  |


### Edit domain names and email in the configuration files

Specify your domain names and contact email for these domains in the [`.env`](.env) file:

```bash
MAIL='mymail@mailfake.com'
## site 1
S1_DOMAIN='test1.fake.com'
## site 2
S2_DOMAIN='test2.foo.com'
```

For two and more domains separate them by comma and use double quotes (`"`) around the variables.

For a single domain double quotes can be omitted:

```bash
S1_DOMAIN="test1.fake.com,test1.bar.com"
```

Configure Nginx virtual hosts

For each domain, you can configure custom Nginx configurations, [`server` block](https://nginx.org/en/docs/http/ngx_http_core_module.html#server) by updating `vhosts/${domain}`:

- `vhosts/test1.fake.com`
- `vhosts/test2.foo.com.`

For example, in `vhost/test2.foo.com`, the custom config redirects the non-www url to `www.test2.foo.com`
```bash
rewrite ^/(.*)$ https://www.test2.foo.com/$1 permanent;
```

### Custom PHP and Nginx upload limits

You can customize the upload limit for Nginx and PHP, editing the files:
- `client_max_upload_size.conf`
- `uploads.ini`

### Create an external Docker network

We are going to use an external network called `multisite-net`, which we will need to create manually:

```bash
docker network create multisite-net
```

## Prepare the solution

Let's do a deployment of the solution. We are going to explain the `docker-compose.yml` file so that it can be easily customized with the necessary services.

In this docker-compose we have 2 sites as example. First site or domain is a Wordpress with a MySQL, connected by an internal network between them. The second site is a Dokuwiki, formed only by a unique container.

- test1.fake.com
  - mysqldb1
  - wordpress1

- test2.foo.com
  - dokukiwi

### Nginx reverse proxy

For this container, we mount the custom upload limits files, the vhosts and certs. Also we expose the 80 and 443 ports. This ports must be accesible from outside the host.

Label is also mandatory in order to work fine with acme-companion.

```yaml
  nginx-proxy:
    image: jwilder/nginx-proxy
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - html:/usr/share/nginx/html
      - dhparam:/etc/nginx/dhparam
      - ./vhost:/etc/nginx/vhost.d
      - certs:/etc/nginx/certs:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./client_max_upload_size.conf:/etc/nginx/conf.d/client_max_upload_size.conf
    restart: always
    networks:
      - multisite-net
```

### Let’s Encrypt Container for SSL Certificates

We use the acme-companion container ir order to generate and obtain the SSL certificates for each defined host. It is importan to set the email for registration.

```yaml
  letsencrypt:
    env_file: .env
    image: nginxproxy/acme-companion
    container_name: acme-companion
    depends_on:
      - "nginx-proxy"
    volumes:
      - certs:/etc/nginx/certs:rw
      - ./vhost:/etc/nginx/vhost.d
      - html:/usr/share/nginx/html
      - acme:/etc/acme.sh
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      DEFAULT_EMAIL: $MAIL
    restart: always
    networks:
      - multisite-net
```

### Site test1.fake.com: Wordpress
This is the service associated to first domain. It is made up of a wordpress instance, and a mysql. We need to set the mandatory variales in `.env` file:

```
S1_MYSQL_DATABASE='db1'
S1_MYSQL_USER='db1_user'
S1_MYSQL_PASSWORD='db1_password'
S1_MYSQL_ROOT_PASSWORD='db1_root'
```

Both mysql and wordpress uses an internal network between them, to improve the security of the solution: `mysqldb1`

```yaml
  mysqldb1:
    env_file: .env
    image: mysql:latest
    environment:
      MYSQL_DATABASE: $S1_MYSQL_DATABASE
      MYSQL_USER: $S1_MYSQL_USER
      MYSQL_PASSWORD: $S1_MYSQL_PASSWORD
      MYSQL_ROOT_PASSWORD: $S1_MYSQL_ROOT_PASSWORD
    volumes:
      - 'mysqldb1:/var/lib/mysql'
    restart: always
    networks:
      - mysqldb1

  wordpress1:
    env_file: .env
    image: wordpress:php8.0-apache
    environment:
      WORDPRESS_DB_HOST: mysqldb1
      WORDPRESS_DB_USER: $S1_MYSQL_USER
      WORDPRESS_DB_PASSWORD: $S1_MYSQL_PASSWORD
      WORDPRESS_DB_NAME: $S1_MYSQL_DATABASE
      WORDPRESS_CONFIG_EXTRA: |
        define('AUTOMATIC_UPDATER_DISABLED', true);
      VIRTUAL_HOST: $S1_DOMAIN
      LETSENCRYPT_HOST: $S1_DOMAIN
    volumes:
      - 'wordpress1:/var/www/html/wp-content'
      - './uploads.ini:/usr/local/etc/php/conf.d/uploads.ini'
    restart: always
    depends_on:
      - mysqldb1
    networks:
      - mysqldb1
      - multisite-net
```

`VIRTUAL_HOST` and `LETSENCRYPT_HOST` are the variables that do the magic with nginx-proxy, indicating that it is necessary to generate the necessary configuration, as well as to create the certificates

### Site test2.foo.com: Dokuwiki
This is the service associated to second domain. In this case it is Dokuwiki, in a single container:

```yaml
  dokuwiki:
    image: linuxserver/dokuwiki
    container_name: dokuwiki
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Madrid
      - VIRTUAL_HOST=$S2_DOMAIN
      - LETSENCRYPT_HOST=$S2_DOMAIN
    volumes:
      - dokuwiki1:/config
    restart: unless-stopped
    networks:
      - multisite-net
```

`VIRTUAL_HOST` and `LETSENCRYPT_HOST` are the variables that do the magic with nginx-proxy, indicating that it is necessary to generate the necessary configuration, as well as to create the certificates

### Volumes and Networks

Finally, we define the networks and volumes that are going to be used. It is important to define the volumes in order to have data persistence:

```yaml
volumes:
  certs:
  html:
  dhparam:
  acme:
  mysqldb1:
  wordpress1:
  dokuwiki1:

networks:
  mysqldb1:
    internal: true
  multisite-net:
    external: true
```

### Environment file

Docker-Compose expects the domain name for each of the sites, MySQL root password, and the WordPress database name, username and password, as environment variables in a `.env` file in the root directory.
Also it is mandatory to especify the e-mail in order to user de Letsencrypt cert.

Create the .env file, or copy from `.env.example`

```bash
nano /<PATH>/.env
```

And define the credentials.
```bash
MAIL='mymail@mailfake.com'
## site 1
S1_DOMAIN='test1.fake.com'
S1_MYSQL_DATABASE='db1'
S1_MYSQL_USER='db1_user'
S1_MYSQL_PASSWORD='db1_password'
S1_MYSQL_ROOT_PASSWORD='db1_root'
## site 2
S2_DOMAIN='test2.foo.com'
````

### Add another service to the solution

If you want to add more services, you just have to:
- Include them inside the `docker-compose.yml`
- Define the necessary variables in `.env`
- Create a file inside `/vhost` with the domain name. This file could be empty, or with your custom config

## Deploy the solution

We are ready to start the solution. The first start will take a few minutes as you have to download the necessary images, generate the certificates, etc.

```bash
docker-compose up -d
```

You will get the following:

```bash
Creating network "multisite_mysqldb1" with the default driver
Creating nginx-proxy        ... done
Creating mysqldb1           ... done
Creating dokuwiki           ... done
Creating wordpress1         ... done
Creating acme-companion     ... done
```

Wait a few minutes. After that, open your internet browser and go to one of your domains, e.g. test1.fake.com. It will be redirected to https://test1.fake.com and shows your wordpress with a valid SSL cert.

## Managing the solution
### Start / Stop

```bash
docker-compose up -d
```

```bash
docker-compose down
```
### Check logs
You can check the logs for all containers:

```bash
docker-compose logs -f
```

Or only for the desired container:

```bash
docker-compose logs -f nginx-proxy
```
### Autostart docker-compose

If you are deploying on a raspberry pi, or a VPS and you want the services to automatically start up when the system starts:

create a systemd service:
```bash
sudo nano /etc/systemd/system/docker-compose-multisite.service 
```

With this content. Be aware of point the `WorkingDirectory` to your real docker-compose.yml folder

```bash
[Unit]
Description=Docker Compose Application Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/<PATH TO DOCKER.COMPOSE.YML>/
ExecStart=docker-compose up -d
ExecStop=docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Enable the service:

```bash
sudo systemctl enable docker-compose-multisite
```

### Data Persistence

Surely you find it interesting to make a backup of the volumes to be able to recover the data in case of disaster. You can dump them to an external disk, or use solutions like syncthing, this is already to everyone's liking.

```
/var/lib/docker/volumes/
├── multisite_acme
├── multisite_certs
├── multisite_dhparam
├── multisite_dokuwiki1
├── multisite_html
├── multisite_mysqldb1
└── multisite_wordpress1
```