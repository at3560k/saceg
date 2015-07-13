#!/bin/bash

#DEFAULTS/GLOBALS

EMAIL="foo@example.org"
COUNTRY="US"
STATE="MA"
LOCALE="anytown"
ORG="example inc"

VERBOSE=0

REAL_OPTIND=
COMMON=
SANS=

# UTILS

function abort {
    echo "$1"
    exit 1
}


function usage {
    cat <<EOF
    $0 [-v] [-e <email>] [-c <country>] [-s <state>] [-l <locale>] [-o <org>]
    commonName [SAN_1 [SAN_i ...] ]

    ex: $0 -e test@example.org www.example.org alt1.example.org alt2.example.org
EOF
    exit 1;
}

function log {
    if [[ $VERBOSE -eq 1 ]] ; then
        echo "$@"
    fi
}

function in_path {
    type -P $1 >/dev/null || abort "$1 : command not found"
}


function csr {
openssl req \
    -config <( echo "${CONFIG}" ) \
    -new \
    -newkey rsa:4096 \
    -days 365 \
    -nodes \
    -x509 \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALE}/O=${ORG}/CN=${COMMON}/emailAddress=${EMAIL}" \
    -keyout ${COMMON}.key \
    -out ${COMMON}.cert 
}


in_path openssl

# Getopt
while getopts "hve:c:s:l:o:" OPT ; do
    echo "OPT: $OPT"
    case $OPT in 
        h)
            usage ;;
        v)
            VERBOSE=1 ;;
        e)
            EMAIL=$OPTARG ;;
        c)
            COUNTRY=$OPTARG ;;
        s) 
            STATE=$OPTARG ;;
        l) 
            LOCALE=$OPTARG ;;
        o) 
            ORG=$OPTARG ;;
    esac
done
shift $((OPTIND-1))

# parse args
if [[ $# -lt 1 ]] ; then
    echo "You must call with at least a common name"
    usage
fi

COMMON=$1
shift;

# DNS.1 is the common name
count=2
for arg in "$@" ; do
    log "SAN Host: $arg"
    printf -v DNS_ALT "DNS.${count} = ${arg}\n"
    SANS+=$DNS_ALT
    count=$((count +1))
done

# openssl.cnf
read -d '' CONFIG<<EOF

HOME			= .
RANDFILE		= \$ENV::HOME/.rnd

####################################################################
[ ca ]
default_ca	= CA_default		# The default ca section

####################################################################
[ CA_default ]

x509_extensions	= usr_cert		# The extentions to add to the cert

name_opt 	= ca_default		# Subject Name options
cert_opt 	= ca_default		# Certificate field options

default_days	= 365			# how long to certify for
default_crl_days= 30			# how long before next CRL
default_md	= default		# use public key default MD
preserve	= no			# keep passed DN ordering
policy		= policy_match

# For the CA policy
[ policy_match ]
countryName		= match
stateOrProvinceName	= match
organizationName	= match
organizationalUnitName	= optional
commonName		= supplied
emailAddress		= optional

# For the 'anything' policy
# At this point in time, you must list all acceptable 'object'
# types.
[ policy_anything ]
countryName		= optional
stateOrProvinceName	= optional
localityName		= optional
organizationName	= optional
organizationalUnitName	= optional
commonName		= supplied
emailAddress		= optional

####################################################################
[ req ]
default_bits		= 2048
default_keyfile 	= privkey.pem
distinguished_name	= req_distinguished_name
attributes		= req_attributes
x509_extensions	= v3_ca	# The extentions to add to the self signed cert

string_mask = utf8only

req_extensions = v3_req # The extensions to add to a certificate request

[ req_distinguished_name ]
countryName			= Country Name (2 letter code)
countryName_default		= AU
countryName_min			= 2
countryName_max			= 2

stateOrProvinceName		= State or Province Name (full name)
stateOrProvinceName_default	= Some-State

localityName			= Locality Name (eg, city)

0.organizationName		= Organization Name (eg, company)
0.organizationName_default	= Internet Widgits Pty Ltd

organizationalUnitName		= Organizational Unit Name (eg, section)

commonName			= Common Name (e.g. server FQDN or YOUR name)
commonName_max			= 64

emailAddress			= Email Address
emailAddress_max		= 64

# SET-ex3			= SET extension number 3

[ req_attributes ]
challengePassword		= A challenge password
challengePassword_min		= 4
challengePassword_max		= 20

unstructuredName		= An optional company name

[ usr_cert ]

basicConstraints=CA:FALSE

# This will be displayed in Netscape's comment listbox.
nsComment			= "OpenSSL Generated Certificate"

# PKIX recommendations harmless if included in all certificates.
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:true
[ crl_ext ]
authorityKeyIdentifier=keyid:always
basicConstraints=CA:FALSE
nsComment			= "OpenSSL Generated Certificate"
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

[alt_names]
DNS.1 = ${COMMON}
${SANS}
EOF

# Actual process
csr
