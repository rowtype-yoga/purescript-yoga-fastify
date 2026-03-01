import ws from "@fastify/websocket";

export const webSocketPlugin = ws;

export const wsRouteImpl = (app, path, handler) => {
  app.get(path, { websocket: true }, (socket, req) => {
    handler(socket)();
  });
};

export const onMessageImpl = (socket, handler) => {
  socket.on("message", (data) => {
    handler(data)();
  });
};

export const onCloseImpl = (socket, handler) => {
  socket.on("close", (code, reason) => {
    handler(code)(reason?.toString() ?? "")();
  });
};

export const onErrorImpl = (socket, handler) => {
  socket.on("error", (err) => {
    handler(err)();
  });
};
