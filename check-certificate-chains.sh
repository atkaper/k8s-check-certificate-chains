#!/bin/bash

# This script checks all *.crt files in this script folder for correct chain ordering.
# It expects the issuers to be in order, and the last one must have issued it self.
# For some reason our certificates were sometimes not complete, or in wrong order, or even overcomplete.
# Ingress/nginx does not like silly certificates, therefore this check routine.
# Use the get-all-k8s-certificates.sh script to read all certificates from kubernetes.
#
# The script just reports on WRONG certificates. Run with "-v" option to also show OK's.
#
# 3/7/2018 Thijs Kaper.

cd "$(dirname "$(realpath "$0")")";

for i in *.crt
do
   rm -rf cert-0[0-9] >/dev/null 2>&1
   csplit -s -f cert- $i '%-----BEGIN CERTIFICATE-----%' '/-----BEGIN CERTIFICATE-----/' '{*}' 

   OK="true"

   >report.txt
   PREV=""
   for crt in `ls -1 cert-0* | sort`
   do
      SUB="`openssl x509 -in $crt -text -noout | grep Subject: | sed \"s/Subject: //g\"`"
      ISS="`openssl x509 -in $crt -text -noout | grep Issuer: | sed \"s/Issuer: //g\"`"

      echo $crt >>report.txt
      echo S: $SUB >>report.txt
      echo I: $ISS >>report.txt

      if [ "$PREV" != "" ]
      then
         if [ "$PREV" != "$SUB" ]
         then
            OK="false"
            echo "*** chain error ***" >>report.txt
         fi
      fi

      if [ "$SUB" == "$ISS" ]
      then
         # should be last in chain, set PREV to nonsense to never match a following one
         PREV="--"
      else
         PREV="$ISS"
      fi
   done

   if [ "$PREV" != "--" ]
   then
      echo "ERROR last one not self signed!" >>report.txt
      OK="false"
   fi

   if [ "$OK" != "true" ]
   then
      echo "ERROR $i"
      cat report.txt
      echo
   else
      if [ "$1" == "-v" ]
      then
         echo "OK $i"
         cat report.txt
         echo
      fi
   fi

   rm -rf cert-0[0-9] >/dev/null 2>&1
done

