module Uplc.SnippetImport
  ( fetchText
  , readFirstFileText
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)
import React.Basic.Events (SyntheticEvent)

foreign import fetchTextImpl :: String -> Effect (Promise String)

foreign import readFirstFileTextImpl :: SyntheticEvent -> Effect (Promise String)

fetchText :: String -> Aff String
fetchText =
  toAffE <<< fetchTextImpl

readFirstFileText :: SyntheticEvent -> Aff String
readFirstFileText =
  toAffE <<< readFirstFileTextImpl
