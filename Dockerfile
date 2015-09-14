FROM ubuntu

RUN apt-get update && apt-get install -yq nodejs npm

RUN mkdir /app
WORKDIR /app

ADD package.json /app/
RUN npm install

ADD server.js /app/
ADD mime-types.json /app/

expose 8081
CMD nodejs server.js
