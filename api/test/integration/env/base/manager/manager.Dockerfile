FROM ubuntu:18.04 AS base

ARG wazuhbranch

RUN apt-get update && apt-get install -y supervisor
ADD base/manager/supervisord.conf /etc/supervisor/conf.d/

RUN apt-get update && apt-get install python python3 git gnupg2 gcc make vim libc6-dev curl policycoreutils automake autoconf libtool apt-transport-https lsb-release python-cryptography sqlite3 -y && curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - && echo "deb https://s3-us-west-1.amazonaws.com/packages-dev.wazuh.com/staging/apt/ unstable main" | tee -a /etc/apt/sources.list.d/wazuh.list

RUN git clone https://github.com/wazuh/wazuh && cd /wazuh && git checkout $wazuhbranch
COPY base/manager/preloaded-vars.conf /wazuh/etc/preloaded-vars.conf
RUN /wazuh/install.sh
#####

COPY configurations/base/manager/config/ossec.conf /aux_testing/etc/ossec.conf
COPY configurations/base/manager/config/test.keys /aux_testing/etc/client.keys
COPY configurations/base/manager/config/agent-groups /aux_testing/queue/agent-groups
COPY configurations/base/manager/config/shared /aux_testing/etc/shared
COPY configurations/base/manager/config/agent-info /aux_testing/queue/agent-info
COPY configurations/base/manager/api.yaml /var/ossec/api/configuration/api.yaml
COPY configurations/base/manager/security.yaml /var/ossec/api/configuration/security/security.yaml
RUN chown ossec:ossec /var/ossec/api/configuration/api.yaml
RUN chown ossec:ossec /var/ossec/api/configuration/security/security.yaml

ARG manager_type

RUN if [ "$manager_type" = "master" ]; then \
        cp -rf /aux_testing/* /var/ossec/; \
        # To keep last_keepalive greater than 1 day
        touch -d "2 days ago" /var/ossec/queue/agent-info/wazuh-agent9-any && touch -d "2 days ago" /var/ossec/queue/agent-info/wazuh-agent10-any; \
    fi

COPY configurations/base/manager/security/base_security_test.sql /configuration_files/
COPY configurations/tmp/manager/ /configuration_files/
#
ADD base/manager/entrypoint.sh /scripts/entrypoint.sh

HEALTHCHECK --retries=30 --interval=10s --timeout=30s --start-period=30s CMD /usr/bin/python3 /configuration_files/healthcheck/healthcheck.py || exit 1
