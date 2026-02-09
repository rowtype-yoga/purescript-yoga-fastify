module Test.Fastify.Main where

import Prelude

import Data.Either (Either(..), isLeft)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Foreign (unsafeToForeign)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)
import Yoga.Fastify.Auth.Argon2 as Argon2
import Yoga.Fastify.Auth.JWT as JWT
import Yoga.Fastify.Fastify as Fastify
import Yoga.Fastify.Plugin.Cors as Cors
import Yoga.Fastify.Plugin.Helmet as Helmet
import Yoga.Fastify.Plugin.RateLimit as RateLimit

spec :: Spec Unit
spec = do
  describe "Yoga.Fastify.Fastify" do
    describe "Server Creation" do
      it "creates fastify instance" do
        app <- liftEffect $ Fastify.fastify {}
        Fastify.close app

      it "creates fastify with bodyLimit" do
        app <- liftEffect $ Fastify.fastify { bodyLimit: 1048576 }
        Fastify.close app

      it "creates fastify with ajv options" do
        app <- liftEffect $ Fastify.fastify
          { ajv: Fastify.ajvOptions { removeAdditional: true, allErrors: false } }
        Fastify.close app

      it "creates fastify with bodyLimit and ajv options" do
        app <- liftEffect $ Fastify.fastify
          { bodyLimit: 524288
          , ajv: Fastify.ajvOptions { removeAdditional: true }
          }
        Fastify.close app

    describe "Route Registration" do
      it "registers a route with schema validation" do
        app <- liftEffect $ Fastify.fastify {}
        liftEffect $ Fastify.route
          { method: Fastify.HTTPMethod "POST"
          , url: Fastify.RouteURL "/validated"
          , schema: Fastify.routeSchema
              { body: Fastify.JsonSchema $ unsafeToForeign
                  { type: "object"
                  , properties: { name: { type: "string" } }
                  , required: [ "name" ]
                  }
              }
          }
          (\_ reply -> Fastify.send (unsafeToForeign "ok") reply)
          app
        Fastify.close app

      it "registers a route with config" do
        app <- liftEffect $ Fastify.fastify {}
        liftEffect $ Fastify.route
          { method: Fastify.HTTPMethod "GET"
          , url: Fastify.RouteURL "/limited"
          , config: Fastify.routeConfig
              { rateLimit: unsafeToForeign { max: 10, timeWindow: "1 minute" } }
          }
          (\_ reply -> Fastify.send (unsafeToForeign "ok") reply)
          app
        Fastify.close app

  describe "Yoga.Fastify.Plugin.Helmet" do
    it "registers helmet with defaults" do
      app <- liftEffect $ Fastify.fastify {}
      Helmet.helmet {} app
      Fastify.close app

    it "registers helmet with CSP directives" do
      app <- liftEffect $ Fastify.fastify {}
      Helmet.helmet
        { contentSecurityPolicy: unsafeToForeign
            { directives: Helmet.cspDirectives
                { defaultSrc: [ "'self'" ]
                , scriptSrc: [ "'self'", "cdn.example.com" ]
                }
            }
        }
        app
      Fastify.close app

    it "registers helmet with HSTS options" do
      app <- liftEffect $ Fastify.fastify {}
      Helmet.helmet
        { hsts: Helmet.hstsOptions
            { maxAge: 31536000
            , includeSubDomains: true
            , preload: true
            }
        }
        app
      Fastify.close app

  describe "Yoga.Fastify.Plugin.Cors" do
    it "registers cors with wildcard origin" do
      app <- liftEffect $ Fastify.fastify {}
      Cors.cors { origin: Cors.originAll } app
      Fastify.close app

    it "registers cors with specific origin" do
      app <- liftEffect $ Fastify.fastify {}
      Cors.cors { origin: Cors.origin "https://example.com" } app
      Fastify.close app

    it "registers cors with origin list" do
      app <- liftEffect $ Fastify.fastify {}
      Cors.cors
        { origin: Cors.originList [ "https://example.com", "https://app.example.com" ]
        , methods: [ "GET", "POST" ]
        }
        app
      Fastify.close app

    it "registers credentialed cors with specific origin" do
      app <- liftEffect $ Fastify.fastify {}
      Cors.corsCredentialed
        { origin: Cors.origin "https://example.com"
        , credentials: true
        }
        app
      Fastify.close app

  -- corsCredentialed { origin: originAll, credentials: true } does not compile:
  -- "Cannot use credentials: true with a wildcard origin"

  describe "Yoga.Fastify.Plugin.RateLimit" do
    it "registers rate limiting with defaults" do
      app <- liftEffect $ Fastify.fastify {}
      RateLimit.rateLimit { max: 100, timeWindow: RateLimit.timeWindowStr "1 minute" } app
      Fastify.close app

    it "registers rate limiting with millisecond window" do
      app <- liftEffect $ Fastify.fastify {}
      RateLimit.rateLimit { max: 50, timeWindow: RateLimit.timeWindowMs 60000 } app
      Fastify.close app

    it "builds per-route rate limit config" do
      let _ = RateLimit.routeRateLimit { max: 10, timeWindow: RateLimit.timeWindowStr "30 seconds" }
      pure unit

  describe "Yoga.Fastify.Auth.Argon2" do
    it "hashes and verifies a password" do
      hashed <- Argon2.hashPassword "mypassword123" {}
      result <- Argon2.verifyPassword hashed "mypassword123"
      result `shouldEqual` true

    it "rejects a wrong password" do
      hashed <- Argon2.hashPassword "mypassword123" {}
      result <- Argon2.verifyPassword hashed "wrongpassword"
      result `shouldEqual` false

    it "hashes with custom options" do
      hashed <- Argon2.hashPassword "mypassword123" { memoryCost: 65536, timeCost: 3 }
      result <- Argon2.verifyPassword hashed "mypassword123"
      result `shouldEqual` true

  describe "Yoga.Fastify.Auth.JWT" do
    it "signs and verifies a token" do
      let secret = JWT.JWTSecret "super-secret-key-that-is-at-least-32-characters-long"
      token <- JWT.signJWT { sub: "user123", role: "admin" } { expiresIn: "1h", issuer: "test-app" } secret
      result :: Either String { sub :: String, role :: String } <- JWT.verifyJWT token { issuer: "test-app" } secret
      case result of
        Right payload -> do
          payload.sub `shouldEqual` "user123"
          payload.role `shouldEqual` "admin"
        Left err -> do
          err `shouldSatisfy` \_ -> false

    it "rejects a token with wrong issuer" do
      let secret = JWT.JWTSecret "super-secret-key-that-is-at-least-32-characters-long"
      token <- JWT.signJWT { sub: "user123" } { issuer: "good-app" } secret
      result :: Either String { sub :: String } <- JWT.verifyJWT token { issuer: "evil-app" } secret
      result `shouldSatisfy` isLeft

    it "rejects a token with wrong secret" do
      let secret1 = JWT.JWTSecret "super-secret-key-that-is-at-least-32-characters-long"
      let secret2 = JWT.JWTSecret "different-secret-key-also-at-least-32-characters!!"
      token <- JWT.signJWT { sub: "user123" } {} secret1
      result :: Either String { sub :: String } <- JWT.verifyJWT token {} secret2
      result `shouldSatisfy` isLeft

main :: Effect Unit
main = launchAff_ $ runSpec [ consoleReporter ] spec
