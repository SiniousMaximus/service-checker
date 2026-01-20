FROM alpine:3.23.2

# Install packages
RUN apk update && apk upgrade && \
    apk add --no-cache openssh python3 py3-yaml py3-requests

# Copy application files
RUN mkdir /etc/service-checker
COPY server.py /etc/service-checker/server.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN chmod +x /etc/service-checker/server.py

CMD ["/bin/sh", "/entrypoint.sh"]
