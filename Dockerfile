FROM node:24-alpine

WORKDIR /app

COPY package*.json .

RUN npm install

COPY . .

CMD [ "node", "--watch", "src/server.js" ]

EXPOSE 3000