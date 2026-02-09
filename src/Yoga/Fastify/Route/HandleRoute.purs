module Yoga.Fastify.Route.HandleRoute
  ( handleRoute
  ) where

import Prelude

import Data.Array as Array
import Data.Array.NonEmpty as NEA
import Data.Either (Either(..), blush)
import Data.Foldable (foldMap)
import Data.Maybe (Maybe(..))
import Data.String as String
import Effect (Effect)
import Effect.Class (liftEffect)
import Prim.Row as Row
import Type.Proxy (Proxy(..))
import Yoga.Fastify.Fastify (Fastify, FastifyReply, FastifyRequest, HTTPMethod(..), RouteURL(..), StatusCode(..))
import Yoga.Fastify.Fastify as F
import Yoga.HTTP.API.Path (class PathPattern, pathPattern)
import Yoga.HTTP.API.Route.Route (Route, class ConvertResponseVariant)
import Yoga.Fastify.Route.HandleResponse (class HandleResponse, handleResponse)
import Yoga.HTTP.API.Route.Handler (Request, class DefaultRequestFields, class SegmentPathParams, class SegmentQueryParams, class EncodingBody)
import Yoga.HTTP.API.Route.RouteHandler (Handler, class RouteHandler, runHandler)
import Yoga.Fastify.Route.ParseBody (class ParseBody, parseBody)
import Yoga.Fastify.Route.ParseHeaders (class ParseHeaders, parseHeaders)
import Yoga.Fastify.Route.ParsePathParams (class ParsePathParams, parsePathParams)
import Yoga.Fastify.Route.ParseQueryParams (class ParseQueryParamsFromObject, parseQueryParamsFromObject)
import Yoga.HTTP.API.Route.RenderMethod (class RenderMethod, renderMethod)
import Yoga.JSON (writeJSON, write)

handleRoute
  :: forall method segments partialRequest o_ fullHeaders fullCookies fullEncoding userResp respVariant
       pathParams queryParams body
   . Row.Union partialRequest o_ (headers :: Record fullHeaders, cookies :: Record fullCookies, body :: fullEncoding)
  => DefaultRequestFields partialRequest fullHeaders fullCookies fullEncoding
  => RenderMethod method
  => PathPattern segments
  => SegmentPathParams segments pathParams
  => SegmentQueryParams segments queryParams
  => EncodingBody fullEncoding body
  => ParsePathParams pathParams
  => ParseQueryParamsFromObject queryParams
  => ParseHeaders fullHeaders
  => ParseBody fullEncoding body
  => ConvertResponseVariant userResp respVariant
  => HandleResponse respVariant
  => RouteHandler (Route method segments (Request (Record partialRequest)) userResp) pathParams queryParams fullHeaders body respVariant
  => Handler (Route method segments (Request (Record partialRequest)) userResp)
  -> Fastify
  -> Effect Unit
handleRoute handler fastify =
  F.route
    { method: HTTPMethod (String.toUpper (renderMethod (Proxy :: Proxy method)))
    , url: RouteURL (pathPattern (Proxy :: Proxy segments))
    }
    routeHandler
    fastify
  where
  routeHandler :: FastifyRequest -> FastifyReply -> _
  routeHandler req reply = do
    paramsObj <- liftEffect $ F.params req
    queryObj <- liftEffect $ F.query req
    headersObj <- liftEffect $ F.headers req
    bodyMaybe <- liftEffect $ F.body req

    let
      pathResult = parsePathParams (Proxy :: Proxy pathParams) paramsObj
      queryResult = parseQueryParamsFromObject (Proxy :: Proxy queryParams) queryObj
      headersResult = parseHeaders (Proxy :: Proxy fullHeaders) headersObj
      bodyResult = parseBody (Proxy :: Proxy fullEncoding) bodyMaybe

      tagField field err = { field, error: err }

      collectErrors = Array.concat
        [ pathResult # blush # foldMap (map (tagField "path"))
        , queryResult # blush # foldMap (map (tagField "query"))
        , headersResult # blush # foldMap (NEA.toArray >>> map (show >>> tagField "headers"))
        , bodyResult # blush # foldMap (pure >>> map (tagField "body"))
        ]

    case NEA.fromArray collectErrors of
      Nothing ->
        case pathResult, queryResult, headersResult, bodyResult of
          Right path, Right query, Right headers, Right body -> do
            result <- (runHandler handler) { path, query, headers, body }
            handleResponse (Proxy :: Proxy respVariant) result reply
          _, _, _, _ -> pure unit -- impossible
      Just errors ->
        send400 reply (writeJSON { error: "Invalid request", details: errors })

  send400 :: FastifyReply -> String -> _
  send400 reply errorJson = do
    void $ liftEffect $ F.status (StatusCode 400) reply
    void $ liftEffect $ F.header "content-type" "application/json" reply
    F.send (write errorJson) reply
