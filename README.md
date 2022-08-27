# Multi-site docker-compose with proxy and SSL

blablabla

## Table of contents

## Prerequisites

## External docker network
We need a custom docker network to connect the diferent containers. We can create it with the folowing command

```bash
docker network create multisite-net
```

## Environment file

Docker Compose expects the MySQL root password, the WordPress database name, username and password as environment variables in a `.env` file in the same directory.

Create the .env file.

$ nano /app/docker-compose-wordpress-nginx-mysql/.env
And define the credentials accordingly.

# MySQL root password
MYSQL_ROOT_PASSWORD='(redacted)'

# WordPress database name, username and password
MYSQL_WORDPRESS_DATABASE='kurtcms_org'
MYSQL_WORDPRESS_USER='kurtcms_org'
MYSQL_WORDPRESS_PASSWORD='(redacted)'

## Start / Stop

```bash
docker-compose up -d
```

```bash
docker-compose down
```

You can check the logs:

```bash
docker-compose logs -f
```

## Docker-Compose

In this docker-compose we have 2 sites (wordpress) as example. Each site or domain is made up of two containers, a database and a wordpress. Both have a specific network disconnected from the rest of the containers.

- test1.fake.com
  - mysqldb1
  - wordpress1

- test2.fake.com
  - mysqldb2
  - wordpress2