FROM node:10-alpine

WORKDIR /opt/camo/
COPY ${PWD} /opt/camo/

RUN npm install && npm cache clean --force

EXPOSE 8081

USER node
CMD ["node", "server.js"]
