import argon2 from "argon2";

export const hashImpl = (password, opts) => {
  return argon2.hash(password, opts);
};

export const hashDefaultImpl = (password) => {
  return argon2.hash(password);
};

export const verifyImpl = (hash, password) => {
  return argon2.verify(hash, password);
};
