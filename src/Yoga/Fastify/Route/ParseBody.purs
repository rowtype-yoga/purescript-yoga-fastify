module Yoga.Fastify.Route.ParseBody
  ( class ParseBody
  , parseBody
  ) where

import Prelude

import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Foreign (Foreign)
import Type.Proxy (Proxy)
import Yoga.HTTP.API.Route.Encoding (JSON, FormData, NoBody)
import Yoga.JSON (class ReadForeign, read)

class ParseBody (encoding :: Type) (body :: Type) | encoding -> body where
  parseBody :: Proxy encoding -> Maybe Foreign -> Either String body

instance ParseBody NoBody Unit where
  parseBody _ _ = Right unit

instance ReadForeign a => ParseBody (JSON a) a where
  parseBody _ bodyMaybe = case bodyMaybe of
    Nothing -> Left "Request body is required"
    Just foreignBody -> lmap show (read foreignBody)

instance ReadForeign a => ParseBody (FormData a) a where
  parseBody _ bodyMaybe = case bodyMaybe of
    Nothing -> Left "Request body is required"
    Just foreignBody -> lmap show (read foreignBody)
