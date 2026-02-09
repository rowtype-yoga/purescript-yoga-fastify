module Yoga.Fastify.Auth.Argon2
  ( HashedPassword(..)
  , hashPassword
  , verifyPassword
  , Argon2OptionsImpl
  ) where

import Prelude

import Data.Newtype (class Newtype)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Prim.Row (class Union)
import Promise (Promise)
import Promise.Aff as Promise

newtype HashedPassword = HashedPassword String

derive instance Newtype HashedPassword _
derive newtype instance Eq HashedPassword
derive newtype instance Show HashedPassword

type Argon2OptionsImpl =
  ( memoryCost :: Int
  , timeCost :: Int
  , parallelism :: Int
  , hashLength :: Int
  )

foreign import hashImpl :: forall opts. EffectFn2 String { | opts } (Promise String)

hashPassword :: forall opts opts_. Union opts opts_ Argon2OptionsImpl => String -> { | opts } -> Aff HashedPassword
hashPassword password opts = do
  let hash = runEffectFn2 hashImpl password opts
  HashedPassword <$> Promise.toAffE hash

foreign import verifyImpl :: EffectFn2 String String (Promise Boolean)

verifyPassword :: HashedPassword -> String -> Aff Boolean
verifyPassword (HashedPassword hash) password =
  runEffectFn2 verifyImpl hash password # Promise.toAffE

foreign import hashDefaultImpl :: EffectFn1 String (Promise String)

hashPasswordDefault :: String -> Aff HashedPassword
hashPasswordDefault password = do
  let hash = runEffectFn1 hashDefaultImpl password
  HashedPassword <$> Promise.toAffE hash
