FROM node:10.15.3-alpine

WORKDIR /opt/camo/
COPY ${PWD} /opt/camo/

RUN npm install && npm cache clean --force

EXPOSE 8081
CMD ["node", "server.js"]
