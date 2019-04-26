FROM node:8.9-alpine

WORKDIR /opt/camo/
ADD ${PWD} /opt/camo/

EXPOSE 8081

RUN npm install
USER nobody
CMD ["npm", "start"]
