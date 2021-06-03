#!/bin/bash

/usr/local/bin/envoy -c /envoy/envoy.json -l debug --log-path
/var/log/debug.log --service-cluster "caseflow-local-dev" --service-node "local-system"
