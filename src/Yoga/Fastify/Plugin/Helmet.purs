module Yoga.Fastify.Plugin.Helmet
  ( helmet
  , HelmetOptionsImpl
  , CspDirectivesImpl
  , HstsOptionsImpl
  , cspDirectives
  , hstsOptions
  ) where

import Prelude

import Effect.Aff (Aff)
import Foreign (Foreign, unsafeToForeign)
import Prim.Row (class Union)
import Yoga.Fastify.Fastify (Fastify)
import Yoga.Fastify.Plugin (FastifyPlugin, register)

foreign import helmetPlugin :: FastifyPlugin

type CspDirectivesImpl =
  ( defaultSrc :: Array String
  , scriptSrc :: Array String
  , styleSrc :: Array String
  , imgSrc :: Array String
  , connectSrc :: Array String
  , fontSrc :: Array String
  , objectSrc :: Array String
  , mediaSrc :: Array String
  , frameSrc :: Array String
  , childSrc :: Array String
  , workerSrc :: Array String
  , frameAncestors :: Array String
  , formAction :: Array String
  , baseUri :: Array String
  , manifestSrc :: Array String
  )

cspDirectives :: forall opts opts_. Union opts opts_ CspDirectivesImpl => { | opts } -> Foreign
cspDirectives = unsafeToForeign

type HstsOptionsImpl =
  ( maxAge :: Int
  , includeSubDomains :: Boolean
  , preload :: Boolean
  )

hstsOptions :: forall opts opts_. Union opts opts_ HstsOptionsImpl => { | opts } -> Foreign
hstsOptions = unsafeToForeign

type HelmetOptionsImpl =
  ( global :: Boolean
  , enableCSPNonces :: Boolean
  , contentSecurityPolicy :: Foreign
  , hsts :: Foreign
  , frameguard :: Foreign
  , dnsPrefetchControl :: Foreign
  , referrerPolicy :: Foreign
  , xssFilter :: Boolean
  )

helmet :: forall opts opts_. Union opts opts_ HelmetOptionsImpl => { | opts } -> Fastify -> Aff Unit
helmet opts app = register helmetPlugin opts app
