module Yoga.Fastify.Plugin.Cors
  ( cors
  , corsCredentialed
  , CorsOptionsImpl
  , CorsCredentialedOptionsImpl
  , Origin
  , AllowAll
  , Specific
  , origin
  , originAll
  , originList
  , class CredentialsSafe
  ) where

import Prelude

import Data.Newtype (class Newtype)
import Effect.Aff (Aff)
import Foreign (Foreign, unsafeToForeign)
import Prim.Row (class Union)
import Prim.TypeError (class Fail, Text, Above)
import Yoga.Fastify.Fastify (Fastify)
import Yoga.Fastify.Plugin (FastifyPlugin, register)

foreign import corsPlugin :: FastifyPlugin

data AllowAll

data Specific

newtype Origin (safety :: Type) = Origin Foreign

derive instance Newtype (Origin safety) _

originAll :: Origin AllowAll
originAll = Origin (unsafeToForeign "*")

origin :: String -> Origin Specific
origin = Origin <<< unsafeToForeign

originList :: Array String -> Origin Specific
originList = Origin <<< unsafeToForeign

class CredentialsSafe (safety :: Type)

instance CredentialsSafe Specific
else instance
  ( Fail
      ( Above
          (Text "Cannot use credentials: true with a wildcard origin (\"*\").")
          ( Above
              (Text "Browsers will reject this configuration.")
              (Text "Use a specific origin via `origin` or `originList` instead.")
          )
      )
  ) =>
  CredentialsSafe AllowAll

type CorsOptionsImpl safety =
  ( origin :: Origin safety
  , methods :: Array String
  , allowedHeaders :: Array String
  , exposedHeaders :: Array String
  , maxAge :: Int
  , preflight :: Boolean
  , strictPreflight :: Boolean
  , hideOptionsRoute :: Boolean
  )

type CorsCredentialedOptionsImpl safety =
  ( origin :: Origin safety
  , credentials :: Boolean
  , methods :: Array String
  , allowedHeaders :: Array String
  , exposedHeaders :: Array String
  , maxAge :: Int
  , preflight :: Boolean
  , strictPreflight :: Boolean
  , hideOptionsRoute :: Boolean
  )

cors
  :: forall safety opts opts_
   . Union opts opts_ (CorsOptionsImpl safety)
  => { | opts }
  -> Fastify
  -> Aff Unit
cors opts app = register corsPlugin opts app

corsCredentialed
  :: forall safety opts opts_
   . CredentialsSafe safety
  => Union opts opts_ (CorsCredentialedOptionsImpl safety)
  => { | opts }
  -> Fastify
  -> Aff Unit
corsCredentialed opts app = register corsPlugin opts app
