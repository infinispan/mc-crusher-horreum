FROM quay.io/infinispan-test/mc-crusher-horreum

USER memcache
ENV HORREUM_PASSWORD user
ENV HORREUM_USERNAME password
ENV KEYCLOAK_URL https://KEYCLOAK_URL:8543
ENV HORREUM_URL https://HORREUM_URL
WORKDIR /mc-crusher
ADD benchmark /benchmark