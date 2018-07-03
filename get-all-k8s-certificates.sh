#!/bin/bash

# Script to read all certificates/keys from kubernetes secrets.
# A second script can be used to verify the chain in the CRT files for correctness.
#
# 3/7/2018 Thijs Kaper.

cd "$(dirname "$(realpath "$0")")";

rm -rf k8s-*-*.crt k8s-*-*.key k8s-*-*.txt k8s-*-*.yml >/dev/null 2>&1

# data contains word-pairs (namespace and secret-name)
data="`kubectl get secret --all-namespaces | grep kubernetes.io/tls | awk '{ print $1 \" \" $2 }'`"

# this while loop uses xargs+read to read TWO fields at a time from data
while read ns item; do
    echo $ns $item

    # export secret in some forms (yml, crt, key)
    kubectl get secret -n $ns $item -o yaml > k8s-$ns-$item.yml
    kubectl get secret -n $ns $item -o json | jq -r '.data."tls.crt"' | base64 -d > k8s-$ns-$item.crt
    kubectl get secret -n $ns $item -o json | jq -r '.data."tls.key"' | base64 -d > k8s-$ns-$item.key

    # get some readable info (note: this does not show the CA chain, just the first crt part)
    openssl x509 -in k8s-$ns-$item.crt -text -noout >k8s-$ns-$item.txt
done < <(echo $data | xargs -n2)


