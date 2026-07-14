module Test.Fastify.Main where

import Prelude

import Data.Array.NonEmpty as NEA
import Data.Either (Either(..), isLeft)
import Data.Maybe (Maybe(..), fromMaybe)
import Effect (Effect)
import Effect.Aff (Aff, attempt, launchAff_)
import Effect.Class (liftEffect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Foreign (Foreign, unsafeToForeign)
import Foreign.Object as Object
import Promise (Promise)
import Promise.Aff as Promise
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)
import Type.Proxy (Proxy(..))
import Yoga.Fastify.Auth.Argon2 as Argon2
import Yoga.Fastify.Auth.JWT as JWT
import Yoga.Fastify.Fastify as Fastify
import Yoga.Fastify.Plugin.Cors as Cors
import Yoga.Fastify.Plugin as Plugin
import Yoga.Fastify.Plugin.Helmet as Helmet
import Yoga.Fastify.Plugin.RateLimit as RateLimit
import Yoga.Fastify.Plugin.WebSocket as WebSocket
import Yoga.Fastify.Route.ParseHeaders (parseHeaders)
import Yoga.Fastify.Route.ParseCookies (CookieError(..), parseCookies)
import Yoga.HTTP.API.Route.Auth (BearerToken(..))
import Yoga.HTTP.API.Route.HeaderError (HeaderError(..))

type PluginHeaders = { cors :: Boolean, helmet :: Boolean }

foreign import pluginHeadersImpl :: EffectFn1 Fastify.Fastify (Promise PluginHeaders)

type InjectResponse =
  { statusCode :: Int
  , body :: String
  , headers :: Object.Object String
  }

foreign import injectImpl :: forall opts. EffectFn2 Fastify.Fastify { | opts } (Promise InjectResponse)

inject :: forall opts. { | opts } -> Fastify.Fastify -> Aff InjectResponse
inject opts app = runEffectFn2 injectImpl app opts # Promise.toAffE

foreign import noOpPlugin :: Plugin.FastifyPlugin
foreign import rejectingPlugin :: Plugin.FastifyPlugin
foreign import streamImpl :: Effect Foreign
foreign import multipartFileTextImpl :: EffectFn1 Foreign String

spec :: Spec Unit
spec = do
  describe "Yoga.Fastify.Fastify" do
    describe "Create and configure a Fastify application" do
      it "use fastify {} when the defaults are enough" do
        app <- liftEffect $ Fastify.fastify {}
        Fastify.close app

      it "set Fastify's request body limit at construction" do
        app <- liftEffect $ Fastify.fastify { bodyLimit: 1048576 }
        Fastify.close app

      it "pass typed AJV options at construction" do
        app <- liftEffect $ Fastify.fastify
          { ajv: Fastify.ajvOptions { removeAdditional: true, allErrors: false } }
        Fastify.close app

      it "combine server and AJV options in one record" do
        app <- liftEffect $ Fastify.fastify
          { bodyLimit: 524288
          , ajv: Fastify.ajvOptions { removeAdditional: true }
          }
        Fastify.close app

      it "requestParsers: configure each built-in parser—or disable it" do
        app <- liftEffect $ Fastify.fastify
          { requestParsers: Fastify.requestParsers
              { cookie: Fastify.disableCookieParser
              , formBody: Fastify.formBodyParser { bodyLimit: 1024 }
              , multipart: Fastify.multipartParser
                  { limits: Fastify.multipartLimits { fileSize: 4096 } }
              }
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

    describe "Header Parsing" do
      it "allows Maybe headers to be absent" do
        let result = parseHeaders (Proxy :: Proxy (authorization :: Maybe BearerToken)) Object.empty
        result `shouldEqual` Right { authorization: Nothing }

      it "parses Maybe headers when present" do
        let headers = Object.singleton "authorization" "Bearer abc123"
        let result = parseHeaders (Proxy :: Proxy (authorization :: Maybe BearerToken)) headers
        result `shouldEqual` Right { authorization: Just (BearerToken "abc123") }

      it "still requires non-Maybe headers" do
        let result = parseHeaders (Proxy :: Proxy (authorization :: BearerToken)) Object.empty
        result `shouldEqual` Left (NEA.singleton (MissingHeader "authorization"))

    describe "Cookie Parsing" do
      it "parses required and optional typed cookies" do
        let cookies =
              Object.insert "visits" "4" (Object.singleton "session" "abc123")
        let result = parseCookies
              (Proxy :: Proxy (session :: String, visits :: Maybe Int))
              cookies
        result `shouldEqual` Right { session: "abc123", visits: Just 4 }

      it "requires non-Maybe cookies" do
        let result = parseCookies (Proxy :: Proxy (session :: String)) Object.empty
        result `shouldEqual` Left (NEA.singleton (MissingCookie "session"))

      it "treats malformed optional cookies as absent" do
        let result = parseCookies
              (Proxy :: Proxy (visits :: Maybe Int))
              (Object.singleton "visits" "not-an-int")
        result `shouldEqual` Right { visits: Nothing }

    describe "Read cookies, forms, uploads, and streams" do
      it "read parsed cookies and URL-encoded fields from the request" do
        app <- liftEffect $ Fastify.fastify {}
        liftEffect $ Fastify.post
          (Fastify.RouteURL "/form")
          ( \request reply -> do
              cookies <- liftEffect $ Fastify.cookies request
              body <- liftEffect $ Fastify.body request
              Fastify.sendJson
                (unsafeToForeign
                  { cookies
                  , body: fromMaybe (unsafeToForeign {}) body
                  })
                reply
          )
          app
        response <- inject
          { method: Fastify.HTTPMethod "POST"
          , url: Fastify.RouteURL "/form"
          , headers:
              { "content-type": "application/x-www-form-urlencoded"
              , cookie: "session=abc123; theme=dark"
              }
          , payload: "name=Ada&count=2"
          }
          app
        response.statusCode `shouldEqual` 200
        response.body `shouldEqual`
          """{"cookies":{"session":"abc123","theme":"dark"},"body":{"name":"Ada","count":"2"}}"""
        Fastify.close app

      it "set a form parser body limit through requestParsers" do
        app <- liftEffect $ Fastify.fastify
          { requestParsers: Fastify.requestParsers
              { formBody: Fastify.formBodyParser { bodyLimit: 4 } }
          }
        liftEffect $ Fastify.post
          (Fastify.RouteURL "/limited-form")
          (\_ reply -> Fastify.send (unsafeToForeign "unexpected") reply)
          app
        response <- inject
          { method: Fastify.HTTPMethod "POST"
          , url: Fastify.RouteURL "/limited-form"
          , headers: { "content-type": "application/x-www-form-urlencoded" }
          , payload: "name=Ada"
          }
          app
        response.statusCode `shouldEqual` 413
        Fastify.close app

      it "receive multipart text fields as a body record" do
        app <- liftEffect $ Fastify.fastify {}
        liftEffect $ Fastify.post
          (Fastify.RouteURL "/multipart")
          ( \request reply -> do
              body <- liftEffect $ Fastify.body request
              Fastify.sendJson (fromMaybe (unsafeToForeign {}) body) reply
          )
          app
        let boundary = "yoga-boundary"
        let payload =
              "--" <> boundary <> "\r\n"
                <> "Content-Disposition: form-data; name=\"name\"\r\n\r\n"
                <> "Ada\r\n"
                <> "--" <> boundary <> "\r\n"
                <> "Content-Disposition: form-data; name=\"role\"\r\n\r\n"
                <> "admin\r\n"
                <> "--" <> boundary <> "--\r\n"
        response <- inject
          { method: Fastify.HTTPMethod "POST"
          , url: Fastify.RouteURL "/multipart"
          , headers: { "content-type": "multipart/form-data; boundary=" <> boundary }
          , payload
          }
          app
        response.statusCode `shouldEqual` 200
        response.body `shouldEqual` """{"name":"Ada","role":"admin"}"""
        Fastify.close app

      it "receive uploaded file bytes without coercing them to JSON" do
        app <- liftEffect $ Fastify.fastify {}
        liftEffect $ Fastify.post
          (Fastify.RouteURL "/upload")
          ( \request reply -> do
              body <- liftEffect $ Fastify.body request
              text <- case body of
                Nothing -> pure ""
                Just value -> liftEffect $ runEffectFn1 multipartFileTextImpl value
              Fastify.send (unsafeToForeign text) reply
          )
          app
        let boundary = "yoga-file-boundary"
        let payload =
              "--" <> boundary <> "\r\n"
                <> "Content-Disposition: form-data; name=\"file\"; filename=\"hello.txt\"\r\n"
                <> "Content-Type: text/plain\r\n\r\n"
                <> "hello from multipart\r\n"
                <> "--" <> boundary <> "--\r\n"
        response <- inject
          { method: Fastify.HTTPMethod "POST"
          , url: Fastify.RouteURL "/upload"
          , headers: { "content-type": "multipart/form-data; boundary=" <> boundary }
          , payload
          }
          app
        response.statusCode `shouldEqual` 200
        response.body `shouldEqual` "hello from multipart"
        Fastify.close app

      it "sends a Web ReadableStream without buffering it as JSON" do
        app <- liftEffect $ Fastify.fastify {}
        liftEffect $ Fastify.get
          (Fastify.RouteURL "/stream")
          ( \_ reply -> do
              _ <- liftEffect $ Fastify.header "content-type" "text/plain" reply
              stream <- liftEffect streamImpl
              Fastify.send stream reply
          )
          app
        response <- inject
          { method: Fastify.HTTPMethod "GET", url: Fastify.RouteURL "/stream" }
          app
        response.statusCode `shouldEqual` 200
        response.body `shouldEqual` "first-second"
        Object.lookup "content-type" response.headers `shouldEqual` Just "text/plain"
        Fastify.close app

  describe "Register Fastify plugins in Aff" do
    it "register multiple plugins sequentially on one application" do
      app <- liftEffect $ Fastify.fastify {}
      liftEffect $ Fastify.get
        (Fastify.RouteURL "/plugins")
        (\_ reply -> Fastify.send (unsafeToForeign "ok") reply)
        app
      Helmet.helmet {} app
      Cors.cors { origin: Cors.originAll } app
      headers <- runEffectFn1 pluginHeadersImpl app # Promise.toAffE
      headers `shouldEqual` { cors: true, helmet: true }
      Fastify.close app

    it "await readiness repeatedly without rerunning plugins" do
      app <- liftEffect $ Fastify.fastify {}
      Helmet.helmet {} app
      liftEffect $ Fastify.get
        (Fastify.RouteURL "/ready")
        (\_ reply -> Fastify.send (unsafeToForeign "ready") reply)
        app
      Fastify.ready app
      Fastify.ready app
      response <- inject { method: Fastify.HTTPMethod "GET", url: Fastify.RouteURL "/ready" } app
      response.statusCode `shouldEqual` 200
      response.body `shouldEqual` "ready"
      Fastify.close app

    it "register: Fastify → Aff Unit, even when app.register returns the app" do
      app <- liftEffect $ Fastify.fastify {}
      Plugin.register noOpPlugin {} app
      Fastify.ready app
      Fastify.close app

    it "surface rejected plugin registration as an Aff error" do
      app <- liftEffect $ Fastify.fastify {}
      result <- attempt $ Plugin.register rejectingPlugin {} app
      result `shouldSatisfy` isLeft

    it "rejects registration after the app is ready" do
      app <- liftEffect $ Fastify.fastify {}
      Fastify.ready app
      result <- attempt $ Helmet.helmet {} app
      result `shouldSatisfy` isLeft
      Fastify.close app

    it "loads the WebSocket plugin from the package dependency" do
      app <- liftEffect $ Fastify.fastify {}
      WebSocket.webSocket {} app
      Fastify.ready app
      Fastify.close app

  describe "Yoga.Fastify reply completion" do
    it "waits for send to complete and resolves the handler with Unit" do
      app <- liftEffect $ Fastify.fastify {}
      liftEffect $ Fastify.get
        (Fastify.RouteURL "/send")
        (\_ reply -> Fastify.send (unsafeToForeign "sent") reply)
        app
      response <- inject { method: Fastify.HTTPMethod "GET", url: Fastify.RouteURL "/send" } app
      response.statusCode `shouldEqual` 200
      response.body `shouldEqual` "sent"
      Fastify.close app

    it "waits for sendJson and preserves reply status and headers" do
      app <- liftEffect $ Fastify.fastify {}
      liftEffect $ Fastify.get
        (Fastify.RouteURL "/json")
        ( \_ reply -> do
            _ <- liftEffect $ Fastify.status (Fastify.StatusCode 201) reply
            _ <- liftEffect $ Fastify.header "x-test" "complete" reply
            Fastify.sendJson (unsafeToForeign { ok: true }) reply
        )
        app
      response <- inject { method: Fastify.HTTPMethod "GET", url: Fastify.RouteURL "/json" } app
      response.statusCode `shouldEqual` 201
      response.body `shouldEqual` """{"ok":true}"""
      Object.lookup "x-test" response.headers `shouldEqual` Just "complete"
      Object.lookup "content-type" response.headers `shouldEqual` Just "application/json; charset=utf-8"
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
