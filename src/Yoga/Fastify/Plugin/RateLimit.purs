module Yoga.Fastify.Plugin.RateLimit
  ( rateLimit
  , RateLimitOptionsImpl
  , RouteRateLimitImpl
  , RouteRateLimit(..)
  , routeRateLimit
  , timeWindowMs
  , timeWindowStr
  ) where

import Prelude

import Data.Newtype (class Newtype)
import Effect.Aff (Aff)
import Foreign (Foreign, unsafeToForeign)
import Prim.Row (class Union)
import Yoga.Fastify.Fastify (Fastify)
import Yoga.Fastify.Plugin (FastifyPlugin, register)

foreign import rateLimitPlugin :: FastifyPlugin

type RateLimitOptionsImpl =
  ( global :: Boolean
  , max :: Int
  , ban :: Int
  , timeWindow :: Foreign
  , cache :: Int
  , allowList :: Array String
  , hook :: String
  , nameSpace :: String
  )

rateLimit :: forall opts opts_. Union opts opts_ RateLimitOptionsImpl => { | opts } -> Fastify -> Aff Unit
rateLimit opts app = register rateLimitPlugin opts app

type RouteRateLimitImpl =
  ( max :: Int
  , timeWindow :: Foreign
  , ban :: Int
  , allowList :: Array String
  )

newtype RouteRateLimit = RouteRateLimit Foreign

derive instance Newtype RouteRateLimit _

routeRateLimit :: forall opts opts_. Union opts opts_ RouteRateLimitImpl => { | opts } -> RouteRateLimit
routeRateLimit opts = RouteRateLimit (unsafeToForeign opts)

timeWindowMs :: Int -> Foreign
timeWindowMs = unsafeToForeign

timeWindowStr :: String -> Foreign
timeWindowStr = unsafeToForeign
