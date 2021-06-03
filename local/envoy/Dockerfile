# This an older version but trying to keep it consistent w/ deployment repo
# Goal of this is to set up a minimal local envoy forward proxy for local
# development purposes. Primarily circuirt breaker implementation
FROM envoyproxy/envoy:v1.14.1
ENV ENVOY_DIR=/envoy
RUN  apt-get update && \
     apt-get install -y \
     nano \
     curl \
     netcat
WORKDIR $ENVOY_DIR 
COPY ./local/envoy  $ENVOY_DIR 
VOLUME $ENVOY_DIR
CMD  /usr/local/bin/envoy -c $ENVOY_DIR/envoy.yaml
