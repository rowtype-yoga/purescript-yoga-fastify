export const pluginHeadersImpl = async (app) => {
  const response = await app.inject({ method: "GET", url: "/plugins" });
  return {
    cors: response.headers["access-control-allow-origin"] === "*",
    helmet: response.headers["x-content-type-options"] === "nosniff",
  };
};

export const injectImpl = (app, opts) =>
  app.inject(opts).then((response) => {
    const headers = {};
    for (const [name, value] of Object.entries(response.headers)) {
      if (typeof value === "string") {
        headers[name] = value;
      } else if (Array.isArray(value)) {
        headers[name] = value.join(", ");
      } else if (value !== undefined) {
        headers[name] = String(value);
      }
    }

    return {
      statusCode: response.statusCode,
      body: response.body,
      headers,
    };
  });

export const noOpPlugin = async () => {};

export const rejectingPlugin = async () => {
  throw new Error("expected plugin rejection");
};

export const multipartFileTextImpl = (body) => body.file.toString("utf8");

export const streamImpl = () =>
  new ReadableStream({
    start(controller) {
      controller.enqueue("first-");
      controller.enqueue("second");
      controller.close();
    },
  });
