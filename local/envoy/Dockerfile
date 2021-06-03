FROM envoyproxy/envoy:v1.14.1
RUN  apt-get update && \
     apt-get install -y \
     nano \
     curl \
     netcat
WORKDIR /envoy
CMD  /usr/local/bin/envoy -c /envoy/envoy.json
