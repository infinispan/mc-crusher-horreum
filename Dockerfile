FROM quay.io/infinispan-test/mc-crusher-horreum

USER memcache
ENV HORREUM_PASSWORD Dg-qe2023
ENV HORREUM_USERNAME dg-qe-bot
ENV KEYCLOAK_URL https://horreum-keycloak.corp.redhat.com:8543
ENV HORREUM_URL https://horreum.corp.redhat.com
WORKDIR /mc-crusher
ADD benchmark /benchmark