module Main where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Exception (throw)
import React.Basic.DOM.Client (createRoot, renderRoot)
import Uplc.App (mkApp)
import Web.DOM.NonElementParentNode (getElementById)
import Web.HTML (window)
import Web.HTML.HTMLDocument (toNonElementParentNode)
import Web.HTML.Window (document)

main :: Effect Unit
main = do
  doc <- document =<< window
  mRoot <- getElementById "root" (toNonElementParentNode doc)
  case mRoot of
    Nothing -> throw "UPLC SPA: #root element not found"
    Just rootEl -> do
      app <- mkApp
      reactRoot <- createRoot rootEl
      renderRoot reactRoot (app unit)
