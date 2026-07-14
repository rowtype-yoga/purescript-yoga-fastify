module Yoga.Fastify.Route.ParseCookies
  ( CookieError(..)
  , class ParseCookies
  , parseCookies
  , class ParseCookiesRL
  , parseCookiesRL
  ) where

import Prelude

import Data.Array.NonEmpty (NonEmptyArray)
import Data.Array.NonEmpty as NEA
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Symbol (class IsSymbol, reflectSymbol)
import Foreign.Object as Object
import Prim.Row as Row
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as RL
import Record as Record
import Type.Proxy (Proxy(..))
import Yoga.HTTP.API.Route.HeaderValue (class HeaderValue, parseHeader)

data CookieError
  = MissingCookie String
  | InvalidCookieValue String String

derive instance Eq CookieError

instance Show CookieError where
  show (MissingCookie name) = "Missing required cookie: " <> name
  show (InvalidCookieValue name reason) = "Invalid cookie '" <> name <> "': " <> reason

class ParseCookies (cookies :: Row Type) where
  parseCookies :: Proxy cookies -> Object.Object String -> Either (NonEmptyArray CookieError) (Record cookies)

instance (RowToList cookies rl, ParseCookiesRL rl cookies) => ParseCookies cookies where
  parseCookies _ = parseCookiesRL (Proxy :: Proxy rl)

class ParseCookiesRL (rl :: RowList Type) (cookies :: Row Type) | rl -> cookies where
  parseCookiesRL :: Proxy rl -> Object.Object String -> Either (NonEmptyArray CookieError) (Record cookies)

instance ParseCookiesRL RL.Nil () where
  parseCookiesRL _ _ = Right {}

instance
  ( IsSymbol name
  , HeaderValue ty
  , ParseCookiesRL tail tailRow
  , Row.Cons name (Maybe ty) tailRow cookies
  , Row.Lacks name tailRow
  ) =>
  ParseCookiesRL (RL.Cons name (Maybe ty) tail) cookies where
  parseCookiesRL _ object = do
    let name = reflectSymbol (Proxy :: Proxy name)
    let valueResult = case Object.lookup name object of
          Nothing -> Right Nothing
          Just value -> case parseHeader value of
            Left _ -> Right Nothing
            Right parsed -> Right (Just parsed)
    let restResult = parseCookiesRL (Proxy :: Proxy tail) object
    appendResult (Record.insert (Proxy :: Proxy name)) valueResult restResult

else instance
  ( IsSymbol name
  , HeaderValue ty
  , ParseCookiesRL tail tailRow
  , Row.Cons name ty tailRow cookies
  , Row.Lacks name tailRow
  ) =>
  ParseCookiesRL (RL.Cons name ty tail) cookies where
  parseCookiesRL _ object = do
    let name = reflectSymbol (Proxy :: Proxy name)
    let valueResult = case Object.lookup name object of
          Nothing -> Left (NEA.singleton (MissingCookie name))
          Just value -> case parseHeader value of
            Left reason -> Left (NEA.singleton (InvalidCookieValue name reason))
            Right parsed -> Right parsed
    let restResult = parseCookiesRL (Proxy :: Proxy tail) object
    appendResult (Record.insert (Proxy :: Proxy name)) valueResult restResult

appendResult
  :: forall value tailRow cookies
   . (value -> Record tailRow -> Record cookies)
  -> Either (NonEmptyArray CookieError) value
  -> Either (NonEmptyArray CookieError) (Record tailRow)
  -> Either (NonEmptyArray CookieError) (Record cookies)
appendResult insert valueResult restResult = case valueResult, restResult of
  Right value, Right rest -> Right (insert value rest)
  Left leftErrors, Left rightErrors -> Left (leftErrors <> rightErrors)
  Left errors, Right _ -> Left errors
  Right _, Left errors -> Left errors
