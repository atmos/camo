FROM node:8.4

WORKDIR /opt/camo/
ADD ${PWD} /opt/camo/

EXPOSE 8081

RUN npm install
USER nobody
CMD ["npm", "start"]
