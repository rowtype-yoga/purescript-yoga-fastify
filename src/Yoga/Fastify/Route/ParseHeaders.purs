module Yoga.Fastify.Route.ParseHeaders
  ( class ParseHeaders
  , parseHeaders
  , class ParseHeadersRL
  , parseHeadersRL
  ) where

import Prelude

import Data.Array.NonEmpty (NonEmptyArray)
import Data.Array.NonEmpty as NEA
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Symbol (class IsSymbol, reflectSymbol)
import Foreign.Object as FObject
import Prim.Row as Row
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Record as Record
import Type.Proxy (Proxy(..))
import Yoga.HTTP.API.Route.HeaderError (HeaderError(..))
import Yoga.HTTP.API.Route.HeaderValue (class HeaderValue, parseHeader)

--------------------------------------------------------------------------------
-- ParseHeaders: Parse headers from Object with error accumulation
--------------------------------------------------------------------------------

-- | Parse a record of headers from an Object, accumulating all errors
-- |
-- | Returns Either (NonEmptyArray HeaderError) (Record headers) to collect all parsing errors
-- |
-- | Examples:
-- |   parseHeaders (Proxy :: Proxy (auth :: String)) obj
-- |     -- Left (NEA.singleton (MissingHeader "auth"))  if missing
-- |     -- Right { auth: "Bearer token" }  if present
class ParseHeaders (headers :: Row Type) where
  parseHeaders :: Proxy headers -> FObject.Object String -> Either (NonEmptyArray HeaderError) (Record headers)

instance (RowToList headers rl, ParseHeadersRL rl headers) => ParseHeaders headers where
  parseHeaders _ = parseHeadersRL (Proxy :: Proxy rl)

-- | Helper class using RowList to accumulate errors
class ParseHeadersRL (rl :: RowList Type) (headers :: Row Type) | rl -> headers where
  parseHeadersRL :: Proxy rl -> FObject.Object String -> Either (NonEmptyArray HeaderError) (Record headers)

-- Base case: empty headers
instance ParseHeadersRL RL.Nil () where
  parseHeadersRL _ _ = Right {}

-- Required header (non-Maybe type)
instance
  ( IsSymbol name
  , HeaderValue ty
  , ParseHeadersRL tail tailRow
  , Row.Cons name ty tailRow headers
  , Row.Lacks name tailRow
  ) =>
  ParseHeadersRL (RL.Cons name ty tail) headers where
  parseHeadersRL _ obj =
    let
      headerName = reflectSymbol (Proxy :: Proxy name)

      -- Try to parse this header
      headerResult = case FObject.lookup headerName obj of
        Nothing -> Left $ NEA.singleton $ MissingHeader headerName
        Just headerValue -> case parseHeader headerValue of
          Left err -> Left $ NEA.singleton $ InvalidHeaderValue headerName err
          Right parsed -> Right parsed

      -- Parse the rest
      restResult = parseHeadersRL (Proxy :: Proxy tail) obj
    in
      -- Accumulate errors from both
      case headerResult, restResult of
        Right header, Right rest -> Right $ Record.insert (Proxy :: Proxy name) header rest
        Left errs1, Left errs2 -> Left $ errs1 <> errs2
        Left errs, Right _ -> Left errs
        Right _, Left errs -> Left errs
