FROM node:8.4
ARG GITBOOK_VERSION=3.2.3
ENV BOOKDIR /gitbook
WORKDIR ${BOOKDIR}
VOLUME [ "/gitbook" ]
EXPOSE 4000
RUN npm install gitbook-cli -g
RUN gitbook fetch $GITBOOK_VERSION
CMD gitbook serve