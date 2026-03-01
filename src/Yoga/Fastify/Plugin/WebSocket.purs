module Yoga.Fastify.Plugin.WebSocket
  ( WebSocket
  , WsData
  , webSocket
  , wsRoute
  , onMessage
  , onClose
  , onError
  , WebSocketOptionsImpl
  ) where

import Prelude

import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn2, EffectFn3, runEffectFn2, runEffectFn3)
import Prim.Row (class Union)
import Yoga.Fastify.Fastify (Fastify)
import Yoga.Fastify.Plugin (FastifyPlugin, register)

foreign import data WebSocket :: Type

foreign import data WsData :: Type

foreign import webSocketPlugin :: FastifyPlugin

type WebSocketOptionsImpl =
  ( maxPayload :: Int
  )

webSocket
  :: forall opts opts_
   . Union opts opts_ WebSocketOptionsImpl
  => { | opts }
  -> Fastify
  -> Aff Unit
webSocket opts app = register webSocketPlugin opts app

foreign import wsRouteImpl :: EffectFn3 Fastify String (WebSocket -> Effect Unit) Unit

wsRoute :: String -> (WebSocket -> Effect Unit) -> Fastify -> Effect Unit
wsRoute path handler app = runEffectFn3 wsRouteImpl app path handler

foreign import onMessageImpl :: EffectFn2 WebSocket (WsData -> Effect Unit) Unit

onMessage :: WebSocket -> (WsData -> Effect Unit) -> Effect Unit
onMessage socket handler = runEffectFn2 onMessageImpl socket handler

foreign import onCloseImpl :: EffectFn2 WebSocket (Int -> String -> Effect Unit) Unit

onClose :: WebSocket -> (Int -> String -> Effect Unit) -> Effect Unit
onClose socket handler = runEffectFn2 onCloseImpl socket handler

foreign import onErrorImpl :: EffectFn2 WebSocket (WsData -> Effect Unit) Unit

onError :: WebSocket -> (WsData -> Effect Unit) -> Effect Unit
onError socket handler = runEffectFn2 onErrorImpl socket handler
