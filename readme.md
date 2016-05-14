* Install dependencies, run
```
bundle
```

* Start redis server
```
redis-server /usr/local/etc/redis.conf
```

* Run code
```
ruby nuvi.rb
```

> Concurrently downloads, extracts and stores data in redis.
> The faster the CPU the faster performance. Increase pool size for more performance