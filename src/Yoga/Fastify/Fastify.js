import fastifyLib from "fastify";

// Create Fastify instance
export const fastifyImpl = (opts) => {
  return fastifyLib(opts);
};

// Register route
export const routeImpl = (app, opts, affToPromise, handler) => {
  app.route({
    method: opts.method,
    url: opts.url,
    handler: async (request, reply) => {
      // Call PureScript handler (returns Aff Unit)
      const affResult = handler(request)(reply);
      // Convert Aff to Promise - fromAff returns Effect (Promise Unit), so call it!
      return affToPromise(affResult)();
    }
  });
};

// Listen
export const listenImpl = (app, opts) => {
  return app.listen(opts);
};

// Close
export const closeImpl = (app) => {
  return app.close();
};

// Request API
export const bodyImpl = (request) => request.body;
export const paramsImpl = (request) => request.params;
export const queryImpl = (request) => request.query;
export const headersImpl = (request) => request.headers;
export const methodImpl = (request) => request.method;
export const urlImpl = (request) => request.url;

// Reply API
export const statusImpl = (reply, code) => reply.status(code);
export const headerImpl = (reply, key, value) => reply.header(key, value);
export const sendImpl = (reply, payload) => reply.send(payload);
export const sendJsonImpl = (reply, payload) => reply.send(payload); // Fastify auto-serializes
