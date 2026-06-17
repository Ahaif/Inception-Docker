FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y nginx openssl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

# Self-signed certificate for local/dev use.
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/C=US/ST=State/L=City/O=Org/CN=example.local" \
    -keyout /etc/nginx/ssl/self.key \
    -out    /etc/nginx/ssl/self.crt

COPY default.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
