module Test.Fastify.Main where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldSatisfy)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)
import Yoga.Fastify.Fastify as Fastify

spec :: Spec Unit
spec = do
  describe "Yoga.Fastify FFI" do
    describe "Server Creation" do
      it "creates fastify instance" do
        _ <- liftEffect $ Fastify.fastify {}
        pure unit

main :: Effect Unit
main = launchAff_ $ runSpec [ consoleReporter ] spec
