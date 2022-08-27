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

Docker-Compose expects the domain name for each of the sites, MySQL root password, and the WordPress database name, username and password, as environment variables in a `.env` file in the root directory.
Also it is mandatory to especify the e-mail in order to user de Letsencrypt cert.

Create the .env file.

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
````

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