#!/bin/bash
set -ex

TYPES="admin kube-proxy kube-scheduler kube-controller-manager service-account"
IP=$(ifconfig|grep en0 -a2|grep inet|cut -d\  -f2)

# First generate a CA so we can self sign the rest of our certificates
# Don't overwrite certs
if [[ ! -f certs/ca.pem ]]; then
    cfssl gencert -initca certs/ca-csr.json | cfssljson -bare certs/ca
fi

# Don't overwrite existing certs
if [[ ! -f certs/kubelet.pem ]]; then
    # the kubelet, or worker, needs to set a few values for hostname when generating the worker certs
    # this should set hostname to the shortname or fqdn, the external ip, and the internal ip as follows:
    # -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP}
    cfssl gencert \
        -ca=certs/ca.pem \
        -ca-key=certs/ca-key.pem \
        -config=certs/config.json \
        -profile=kubernetes \
        -hostname=kubelet,${IP} \
        certs/kubelet-csr.json | cfssljson -bare certs/kubelet
fi

if [[ ! -f certs/kubelet.pem ]]; then
    # The API server also needs hostnames set specifically to properly generate it's certificate
    cfssl gencert \
        -ca=certs/ca.pem \
        -ca-key=certs/ca-key.pem \
        -config=certs/config.json \
        -profile=kubernetes \
        -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${IP},127.0.0.1,kubernetes.default \
        certs/kubelet-csr.json | cfssljson -bare certs/kubelet
fi

# Don't overwrite certs
# We check to see if the service-account.pem exists, since it would be the last cert generated.
# This is to avoid unnecessary work if the certs have already been generated.
if [[ ! -f certs/service-account.pem ]]; then
    # iterate through our csrs and all types of certs we need to generate
    for TYPE in $TYPES; do
        echo "Generating cert for ${TYPE}";
        cfssl gencert \
            -ca=certs/ca.pem \
            -ca-key=certs/ca-key.pem \
            -config=certs/config.json \
            -profile=kubernetes \
            certs/${TYPE}-csr.json | cfssljson -bare certs/${TYPE}
    done
fi
