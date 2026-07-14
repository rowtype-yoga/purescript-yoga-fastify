module Yoga.Fastify.Plugin
  ( FastifyPlugin
  , register
  ) where

import Prelude

import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn3, runEffectFn3)
import Promise (Promise)
import Promise.Aff as Promise
import Yoga.Fastify.Fastify (Fastify)

foreign import data FastifyPlugin :: Type

foreign import registerImpl :: forall opts. EffectFn3 Fastify FastifyPlugin { | opts } (Promise Unit)

-- | Queue a plugin registration.
-- |
-- | The returned `Aff` completes once Fastify accepts the registration. Use
-- | `Yoga.Fastify.Fastify.ready` to wait for plugin effects and failures.
register :: forall opts. FastifyPlugin -> { | opts } -> Fastify -> Aff Unit
register plugin opts app = runEffectFn3 registerImpl app plugin opts # Promise.toAffE
