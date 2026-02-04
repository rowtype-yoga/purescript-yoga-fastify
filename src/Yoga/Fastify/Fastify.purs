module Yoga.Fastify.Fastify
  ( -- * Types
    Fastify
  , FastifyRequest
  , FastifyReply
  , RouteHandler
  -- * Newtypes
  , Host(..)
  , Port(..)
  , HTTPMethod(..)
  , RouteURL(..)
  , StatusCode(..)
  -- * Type Rows
  , ListenOptionsImpl
  , RouteOptionsImpl
  , FastifyOptionsImpl
  -- * Creation
  , fastify
  -- * Route Registration
  , route
  , get
  , post
  , put
  , delete
  , patch
  -- * Server Lifecycle
  , listen
  , close
  -- * Request API
  , body
  , params
  , query
  , headers
  , method
  , url
  -- * Reply API
  , status
  , header
  , send
  , sendJson
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, EffectFn4, runEffectFn1, runEffectFn2, runEffectFn3, runEffectFn4)
import Foreign (Foreign)
import Foreign.Object (Object)
import Prim.Row (class Union)
import Promise (Promise)
import Promise.Aff as Promise

-- | Opaque Fastify instance
foreign import data Fastify :: Type

-- | Opaque request object
foreign import data FastifyRequest :: Type

-- | Opaque reply object
foreign import data FastifyReply :: Type

-- | Route handler type: takes request and reply, returns Aff Unit
type RouteHandler = FastifyRequest -> FastifyReply -> Aff Unit

--------------------------------------------------------------------------------
-- Newtypes
--------------------------------------------------------------------------------

newtype Host = Host String

derive instance Newtype Host _
derive newtype instance Show Host

newtype Port = Port Int

derive instance Newtype Port _
derive newtype instance Show Port

newtype HTTPMethod = HTTPMethod String

derive instance Newtype HTTPMethod _
derive newtype instance Show HTTPMethod

newtype RouteURL = RouteURL String

derive instance Newtype RouteURL _
derive newtype instance Show RouteURL

newtype StatusCode = StatusCode Int

derive instance Newtype StatusCode _
derive newtype instance Show StatusCode

--------------------------------------------------------------------------------
-- Fastify Creation
--------------------------------------------------------------------------------

type FastifyOptionsImpl =
  ( logger :: Boolean
  , disableRequestLogging :: Boolean
  , requestIdHeader :: String
  , requestIdLogLabel :: String
  )

type FastifyOptions = { | FastifyOptionsImpl }

-- | Create a Fastify instance
foreign import fastifyImpl :: forall opts. EffectFn1 { | opts } Fastify

fastify :: forall opts opts_. Union opts opts_ FastifyOptionsImpl => { | opts } -> Effect Fastify
fastify opts = runEffectFn1 fastifyImpl opts

--------------------------------------------------------------------------------
-- Route Registration
--------------------------------------------------------------------------------

type RouteOptionsImpl =
  ( method :: HTTPMethod
  , url :: RouteURL
  )

type RouteOptions = { | RouteOptionsImpl }

-- | Register a route with handler
foreign import routeImpl :: forall opts. EffectFn4 Fastify { | opts } (Aff Unit -> Effect (Promise Unit)) RouteHandler Unit

route
  :: forall opts opts_
   . Union opts opts_ RouteOptionsImpl
  => { | opts }
  -> RouteHandler
  -> Fastify
  -> Effect Unit
route opts handler app = runEffectFn4 routeImpl app opts Promise.fromAff handler

-- | Convenience: GET route
get :: RouteURL -> RouteHandler -> Fastify -> Effect Unit
get routeUrl handler = route { method: HTTPMethod "GET", url: routeUrl } handler

-- | Convenience: POST route
post :: RouteURL -> RouteHandler -> Fastify -> Effect Unit
post routeUrl handler = route { method: HTTPMethod "POST", url: routeUrl } handler

-- | Convenience: PUT route
put :: RouteURL -> RouteHandler -> Fastify -> Effect Unit
put routeUrl handler = route { method: HTTPMethod "PUT", url: routeUrl } handler

-- | Convenience: DELETE route
delete :: RouteURL -> RouteHandler -> Fastify -> Effect Unit
delete routeUrl handler = route { method: HTTPMethod "DELETE", url: routeUrl } handler

-- | Convenience: PATCH route
patch :: RouteURL -> RouteHandler -> Fastify -> Effect Unit
patch routeUrl handler = route { method: HTTPMethod "PATCH", url: routeUrl } handler

--------------------------------------------------------------------------------
-- Server Lifecycle
--------------------------------------------------------------------------------

type ListenOptionsImpl =
  ( port :: Port
  , host :: Host
  )

type ListenOptions = { | ListenOptionsImpl }

-- | Start listening
foreign import listenImpl :: forall opts. EffectFn2 Fastify { | opts } (Promise String)

listen :: forall opts opts_. Union opts opts_ ListenOptionsImpl => { | opts } -> Fastify -> Aff String
listen opts app = runEffectFn2 listenImpl app opts # Promise.toAffE

-- | Close the server
foreign import closeImpl :: EffectFn1 Fastify (Promise Unit)

close :: Fastify -> Aff Unit
close = runEffectFn1 closeImpl >>> Promise.toAffE

--------------------------------------------------------------------------------
-- Request API
--------------------------------------------------------------------------------

-- | Get request body (parsed)
foreign import bodyImpl :: EffectFn1 FastifyRequest (Nullable Foreign)

body :: FastifyRequest -> Effect (Maybe Foreign)
body req = runEffectFn1 bodyImpl req <#> toMaybe

-- | Get route params
foreign import paramsImpl :: EffectFn1 FastifyRequest (Object String)

params :: FastifyRequest -> Effect (Object String)
params = runEffectFn1 paramsImpl

-- | Get query params (Foreign - use yoga-json to decode)
foreign import queryImpl :: EffectFn1 FastifyRequest (Object Foreign)

query :: FastifyRequest -> Effect (Object Foreign)
query = runEffectFn1 queryImpl

-- | Get headers
foreign import headersImpl :: EffectFn1 FastifyRequest (Object String)

headers :: FastifyRequest -> Effect (Object String)
headers = runEffectFn1 headersImpl

-- | Get HTTP method
foreign import methodImpl :: EffectFn1 FastifyRequest String

method :: FastifyRequest -> Effect HTTPMethod
method req = runEffectFn1 methodImpl req <#> HTTPMethod

-- | Get request URL
foreign import urlImpl :: EffectFn1 FastifyRequest String

url :: FastifyRequest -> Effect RouteURL
url req = runEffectFn1 urlImpl req <#> RouteURL

--------------------------------------------------------------------------------
-- Reply API
--------------------------------------------------------------------------------

-- | Set status code
foreign import statusImpl :: EffectFn2 FastifyReply StatusCode FastifyReply

status :: StatusCode -> FastifyReply -> Effect FastifyReply
status code reply = runEffectFn2 statusImpl reply code

-- | Set header
foreign import headerImpl :: EffectFn3 FastifyReply String String FastifyReply

header :: String -> String -> FastifyReply -> Effect FastifyReply
header key value reply = runEffectFn3 headerImpl reply key value

-- | Send response (any type)
foreign import sendImpl :: EffectFn2 FastifyReply Foreign (Promise Unit)

send :: Foreign -> FastifyReply -> Aff Unit
send payload reply = runEffectFn2 sendImpl reply payload # Promise.toAffE

-- | Send JSON response (helper that stringifies)
foreign import sendJsonImpl :: EffectFn2 FastifyReply Foreign (Promise Unit)

sendJson :: Foreign -> FastifyReply -> Aff Unit
sendJson payload reply = runEffectFn2 sendJsonImpl reply payload # Promise.toAffE
