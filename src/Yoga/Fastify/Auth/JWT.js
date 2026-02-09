import { SignJWT, jwtVerify } from "jose";

export const signImpl = (payload, opts, secret) => {
  const secretKey = new TextEncoder().encode(secret);
  let builder = new SignJWT(payload).setProtectedHeader({ alg: "HS256" });
  if (opts.expiresIn) builder = builder.setExpirationTime(opts.expiresIn);
  if (opts.audience) builder = builder.setAudience(opts.audience);
  if (opts.issuer) builder = builder.setIssuedAt().setIssuer(opts.issuer);
  if (opts.subject) builder = builder.setSubject(opts.subject);
  if (opts.jwtId) builder = builder.setJti(opts.jwtId);
  return builder.sign(secretKey);
};

export const verifyImpl = (token, opts, secret) => {
  const secretKey = new TextEncoder().encode(secret);
  const verifyOpts = {};
  if (opts.audience) verifyOpts.audience = opts.audience;
  if (opts.issuer) verifyOpts.issuer = opts.issuer;
  if (opts.subject) verifyOpts.subject = opts.subject;
  if (opts.maxTokenAge) verifyOpts.maxTokenAge = opts.maxTokenAge;
  if (opts.requiredClaims) verifyOpts.requiredClaims = opts.requiredClaims;
  return jwtVerify(token, secretKey, verifyOpts).then((result) => result.payload);
};
