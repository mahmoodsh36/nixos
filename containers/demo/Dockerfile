FROM docker.io/library/alpine:3.21

ARG GREETING="hello from the demo"
RUN mkdir -p /www && echo "$GREETING" > /www/index.html

CMD ["tail", "-f", "/dev/null"]
