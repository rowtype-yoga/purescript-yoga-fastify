export const registerImpl = async (app, plugin, opts) => {
  await app.register(plugin, opts);
};
