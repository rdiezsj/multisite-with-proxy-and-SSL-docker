rewrite ^/(.*)$ https://www.test2.fake.com/$1 permanent;