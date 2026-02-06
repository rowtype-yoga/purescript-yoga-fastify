module Yoga.Fastify.Route.ParsePathParams
  ( class ParsePathParams
  , parsePathParams
  , class ParsePathParamsRL
  , parsePathParamsRL
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Symbol (class IsSymbol, reflectSymbol)
import Foreign.Object (Object)
import Foreign.Object as Object
import Prim.Row (class Cons, class Lacks)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Record as Record
import Type.Proxy (Proxy(..))
import Yoga.HTTP.API.Path (class ParseParam, parseParam)

class ParsePathParams (params :: Row Type) where
  parsePathParams :: Proxy params -> Object String -> Either (Array String) (Record params)

instance (RowToList params rl, ParsePathParamsRL rl params) => ParsePathParams params where
  parsePathParams _ = parsePathParamsRL (Proxy :: Proxy rl)

class ParsePathParamsRL (rl :: RowList Type) (params :: Row Type) | rl -> params where
  parsePathParamsRL :: Proxy rl -> Object String -> Either (Array String) (Record params)

instance ParsePathParamsRL RL.Nil () where
  parsePathParamsRL _ _ = Right {}

instance
  ( IsSymbol name
  , ParseParam ty
  , ParsePathParamsRL tail tailRow
  , Cons name ty tailRow params
  , Lacks name tailRow
  ) =>
  ParsePathParamsRL (RL.Cons name ty tail) params where
  parsePathParamsRL _ obj =
    let
      key = Proxy :: Proxy name
      keyName = reflectSymbol key
      valueResult = case Object.lookup keyName obj of
        Nothing -> Left [ "Missing path parameter: " <> keyName ]
        Just str -> case parseParam str of
          Left err -> Left [ "Invalid path parameter '" <> keyName <> "': " <> err ]
          Right value -> Right value
      restResult = parsePathParamsRL (Proxy :: Proxy tail) obj
    in
      case valueResult, restResult of
        Right value, Right rest -> Right (Record.insert key value rest)
        Left errs1, Left errs2 -> Left (errs1 <> errs2)
        Left errs, Right _ -> Left errs
        Right _, Left errs -> Left errs
