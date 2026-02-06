module Yoga.Fastify.Route.ParseQueryParams
  ( class ParseQueryParamsFromObject
  , parseQueryParamsFromObject
  , class ParseQueryParamsFromObjectRL
  , parseQueryParamsFromObjectRL
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Symbol (class IsSymbol, reflectSymbol)
import Foreign (Foreign)
import Foreign.Object (Object)
import Foreign.Object as Object
import Prim.Row (class Cons, class Lacks)
import Prim.RowList (RowList)
import Prim.RowList as RL
import Record as Record
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)
import Yoga.HTTP.API.Path (class ParseParam, parseParam)

class ParseQueryParamsFromObject (query :: Row Type) where
  parseQueryParamsFromObject :: Proxy query -> Object Foreign -> Either (Array String) (Record query)

instance (RL.RowToList query rl, ParseQueryParamsFromObjectRL rl query) => ParseQueryParamsFromObject query where
  parseQueryParamsFromObject _ = parseQueryParamsFromObjectRL (Proxy :: Proxy rl)

class ParseQueryParamsFromObjectRL (rl :: RowList Type) (query :: Row Type) | rl -> query where
  parseQueryParamsFromObjectRL :: Proxy rl -> Object Foreign -> Either (Array String) (Record query)

instance ParseQueryParamsFromObjectRL RL.Nil () where
  parseQueryParamsFromObjectRL _ _ = Right {}

-- Optional field (Maybe ty): always succeeds
instance
  ( IsSymbol name
  , ParseParam ty
  , ParseQueryParamsFromObjectRL tail tailRow
  , Cons name (Maybe ty) tailRow query
  , Lacks name tailRow
  ) =>
  ParseQueryParamsFromObjectRL (RL.Cons name (Maybe ty) tail) query where
  parseQueryParamsFromObjectRL _ obj =
    let
      key = Proxy :: Proxy name
      keyName = reflectSymbol key
      value = case Object.lookup keyName obj of
        Nothing -> Nothing
        Just foreignVal ->
          let
            valueStr = unsafeCoerce foreignVal :: String
          in
            case parseParam valueStr of
              Left _ -> Nothing
              Right v -> Just v
      restResult = parseQueryParamsFromObjectRL (Proxy :: Proxy tail) obj
    in
      case restResult of
        Right rest -> Right (Record.insert key value rest)
        Left errs -> Left errs

-- Required field (plain ty): fails if missing or unparseable
else instance
  ( IsSymbol name
  , ParseParam ty
  , ParseQueryParamsFromObjectRL tail tailRow
  , Cons name ty tailRow query
  , Lacks name tailRow
  ) =>
  ParseQueryParamsFromObjectRL (RL.Cons name ty tail) query where
  parseQueryParamsFromObjectRL _ obj =
    let
      key = Proxy :: Proxy name
      keyName = reflectSymbol key
      valueResult = case Object.lookup keyName obj of
        Nothing -> Left [ "Missing required query parameter: " <> keyName ]
        Just foreignVal ->
          let
            valueStr = unsafeCoerce foreignVal :: String
          in
            case parseParam valueStr of
              Left err -> Left [ "Invalid query parameter '" <> keyName <> "': " <> err ]
              Right value -> Right value
      restResult = parseQueryParamsFromObjectRL (Proxy :: Proxy tail) obj
    in
      case valueResult, restResult of
        Right value, Right rest -> Right (Record.insert key value rest)
        Left errs1, Left errs2 -> Left (errs1 <> errs2)
        Left errs, Right _ -> Left errs
        Right _, Left errs -> Left errs
