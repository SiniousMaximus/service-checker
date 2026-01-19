FROM alpine:3.23.2

# Install packages
RUN apk update && apk upgrade && \
    apk add --no-cache openssh python3 py3-yaml

# Create user
RUN adduser -D checker

# Set working directory
WORKDIR /home/checker

# Copy application files
COPY --chown=checker:checker server.py /home/checker/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

CMD ["/bin/sh", "/entrypoint.sh"]