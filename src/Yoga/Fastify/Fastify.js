import fastifyLib from "fastify";
import cookie from "@fastify/cookie";
import formbody from "@fastify/formbody";
import multipart from "@fastify/multipart";
import { Readable } from "node:stream";

// Create Fastify instance
export const fastifyImpl = (opts) => {
  const { requestParsers = {}, ...fastifyOptions } = opts;
  const app = fastifyLib(fastifyOptions);

  if (requestParsers.cookie !== false) {
    app.register(cookie, requestParsers.cookie ?? {});
  }
  if (requestParsers.formBody !== false) {
    app.register(formbody, requestParsers.formBody ?? {});
  }
  if (requestParsers.multipart !== false) {
    app.register(multipart, {
      ...(requestParsers.multipart ?? {}),
      attachFieldsToBody: "keyValues",
    });
  }
  return app;
};

// Register route
export const routeImpl = (app, opts, affToPromise, handler) => {
  app.route({
    ...opts,
    handler: async (request, reply) => {
      const affResult = handler(request)(reply);
      return affToPromise(affResult)();
    },
  });
};

// Wait for all registered plugins. Fastify returns a native Promise here;
// map its result so the Promise Unit boundary always resolves to undefined.
export const readyImpl = (app) => {
  return app.ready().then(() => undefined);
};

// Listen
export const listenImpl = (app, opts) => {
  return app.listen(opts);
};

// Close returns a native Promise; normalize its Promise Unit result explicitly.
export const closeImpl = (app) => {
  return app.close().then(() => undefined);
};

// Request API
export const bodyImpl = (request) => request.body;
export const paramsImpl = (request) => request.params;
export const queryImpl = (request) => request.query;
export const headersImpl = (request) => request.headers;
export const cookiesImpl = (request) => request.cookies ?? {};
export const methodImpl = (request) => request.method;
export const urlImpl = (request) => request.url;

// Reply API
export const statusImpl = (reply, code) => reply.status(code);
export const headerImpl = (reply, key, value) => reply.header(key, value);
// FastifyReply is a lifecycle-aware thenable, not a native Promise. Assimilate
// it into a stable Promise and erase the reply value at the Promise Unit edge.
const responsePayload = (payload) =>
  payload != null && typeof payload.getReader === "function"
    ? Readable.fromWeb(payload)
    : payload;

export const sendImpl = (reply, payload) =>
  Promise.resolve(reply.send(responsePayload(payload))).then(() => undefined);
export const sendJsonImpl = (reply, payload) =>
  Promise.resolve(reply.send(payload)).then(() => undefined);

// Raw Node access
export const rawRequestImpl = (request) => request.raw;
export const rawReplyImpl = (reply) => reply.raw;
export const rawRouteImpl = (app, methods, handler) => {
  app.route({
    method: methods,
    url: "/*",
    handler: (req, reply) => {
      handler(req.raw)(reply.raw)();
      reply.hijack();
    },
  });
};

export const rawServerImpl = (app) => app.server;

export const onUpgradeImpl = (server, handler) => {
  server.on("upgrade", (req, socket, head) => {
    handler(req)(socket)(head)();
  });
};

export const httpRequestUrlImpl = (req) => req.url;
