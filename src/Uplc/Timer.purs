module Uplc.Timer
  ( TimeoutId
  , setTimeout
  , clearTimeout
  ) where

import Prelude

import Effect (Effect)

foreign import data TimeoutId :: Type

foreign import setTimeout :: Int -> Effect Unit -> Effect TimeoutId

foreign import clearTimeout :: TimeoutId -> Effect Unit
