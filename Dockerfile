# ---- Base image -------------------------------------------------------------
# Alpine is a very small Linux distribution (~5 MB), ideal for CLI tools.
FROM alpine:3.20

# ---- Packages ---------------------------------------------------------------
# Only bash is needed: the scripts use bash features, and Alpine ships with
# busybox (df, uname, ping, timeout ...) which already covers everything else.
# --no-cache avoids leaving the package index in the image.
RUN apk add --no-cache bash

# ---- Non-root user ----------------------------------------------------------
# Running as an unprivileged user is a Docker security best practice.
RUN addgroup -S diag && adduser -S -G diag diag

# ---- Application ------------------------------------------------------------
WORKDIR /app
COPY app/ /app/

# Set executable permissions and expose the tool as a `diagnostic` command.
RUN chmod +x /app/*.sh && ln -s /app/diagnostic.sh /usr/local/bin/diagnostic

USER diag

# ENTRYPOINT is fixed, so `docker run diagnostic-tool <args>` passes <args>
# straight to the tool. CMD is only the default when no argument is given.
ENTRYPOINT ["/app/diagnostic.sh"]
CMD ["help"]
