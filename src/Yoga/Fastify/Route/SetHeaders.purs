module Yoga.Fastify.Route.SetHeaders
  ( class SetHeaders
  , setHeaders
  , class SetHeadersRL
  , setHeadersRL
  ) where

import Prelude

import Data.Symbol (class IsSymbol, reflectSymbol)
import Effect (Effect)
import Prim.Row (class Cons, class Lacks)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Record as Record
import Type.Proxy (Proxy(..))
import Yoga.Fastify.Fastify as F

class SetHeaders (headers :: Row Type) where
  setHeaders :: Record headers -> F.FastifyReply -> Effect F.FastifyReply

instance (RowToList headers rl, SetHeadersRL rl headers) => SetHeaders headers where
  setHeaders = setHeadersRL (Proxy :: Proxy rl)

class SetHeadersRL (rl :: RowList Type) (headers :: Row Type) | rl -> headers where
  setHeadersRL :: Proxy rl -> Record headers -> F.FastifyReply -> Effect F.FastifyReply

instance SetHeadersRL RL.Nil () where
  setHeadersRL _ _ reply = pure reply

instance
  ( IsSymbol name
  , SetHeadersRL tail tailRow
  , Cons name String tailRow headers
  , Lacks name tailRow
  ) =>
  SetHeadersRL (RL.Cons name String tail) headers where
  setHeadersRL _ headers reply = do
    let
      headerName = reflectSymbol (Proxy :: Proxy name)
      value = Record.get (Proxy :: Proxy name) headers
      tailHeaders = Record.delete (Proxy :: Proxy name) headers :: Record tailRow
    reply' <- F.header headerName value reply
    setHeadersRL (Proxy :: Proxy tail) tailHeaders reply'
