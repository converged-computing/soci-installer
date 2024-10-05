FROM ubuntu:22.04
# docker build -t ghcr.io/converged-computing/soci-installer:latest .
# docker push ghcr.io/converged-computing/soci-installer:latest
WORKDIR /soci-install
COPY docker/* .
RUN chmod +x /soci-install/entrypoint.sh
ENTRYPOINT ["/soci-install/entrypoint.sh"]
