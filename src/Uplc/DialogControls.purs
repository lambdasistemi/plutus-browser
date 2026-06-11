module Uplc.DialogControls
  ( menu
  , menuItem
  , selectField
  ) where

import React.Basic (JSX)

foreign import selectField :: forall r. Record r -> Array JSX -> JSX

foreign import menu :: forall r. Record r -> Array JSX -> JSX

foreign import menuItem :: forall r. Record r -> Array JSX -> JSX
