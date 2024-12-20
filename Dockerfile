FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    mysql-client \
    wget \
    yq

WORKDIR /app

COPY txcli.sh ./txcli.sh

RUN chmod +x ./txcli.sh

ENV DB_CONN_STR=""
ENV RECIPE_URL=""

CMD ["bash", "-c", "./txcli.sh"]
