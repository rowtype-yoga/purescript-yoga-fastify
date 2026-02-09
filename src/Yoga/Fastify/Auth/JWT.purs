module Yoga.Fastify.Auth.JWT
  ( JWTSecret(..)
  , SignOptionsImpl
  , VerifyOptionsImpl
  , signJWT
  , verifyJWT
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Newtype (class Newtype)
import Effect.Aff (Aff, attempt)
import Effect.Uncurried (EffectFn3, runEffectFn3)
import Foreign (Foreign)
import Prim.Row (class Union)
import Promise (Promise)
import Promise.Aff as Promise
import Yoga.JSON (class ReadForeign, class WriteForeign, writeImpl, read)

newtype JWTSecret = JWTSecret String

derive instance Newtype JWTSecret _

type SignOptionsImpl =
  ( expiresIn :: String
  , audience :: String
  , issuer :: String
  , subject :: String
  , jwtId :: String
  )

type VerifyOptionsImpl =
  ( audience :: String
  , issuer :: String
  , subject :: String
  , maxTokenAge :: String
  , requiredClaims :: Array String
  )

foreign import signImpl :: forall opts. EffectFn3 Foreign { | opts } String (Promise String)

signJWT
  :: forall payload opts opts_
   . WriteForeign payload
  => Union opts opts_ SignOptionsImpl
  => payload
  -> { | opts }
  -> JWTSecret
  -> Aff String
signJWT payload opts (JWTSecret secret) = do
  let foreignPayload = writeImpl payload
  runEffectFn3 signImpl foreignPayload opts secret # Promise.toAffE

foreign import verifyImpl :: forall opts. EffectFn3 String { | opts } String (Promise Foreign)

verifyJWT
  :: forall payload opts opts_
   . ReadForeign payload
  => Union opts opts_ VerifyOptionsImpl
  => String
  -> { | opts }
  -> JWTSecret
  -> Aff (Either String payload)
verifyJWT token opts (JWTSecret secret) = do
  result <- attempt (runEffectFn3 verifyImpl token opts secret # Promise.toAffE)
  pure case result of
    Left err -> Left (show err)
    Right foreign_ -> case read foreign_ of
      Left errs -> Left (show errs)
      Right payload -> Right payload
