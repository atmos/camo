FROM ubuntu

WORKDIR /app

RUN apt-get update && apt-get install -yq nodejs npm

ADD package.json /app/
RUN npm install

ADD server.js /app/
ADD mime-types.json /app/

EXPOSE 8081
USER nobody
CMD nodejs server.js
