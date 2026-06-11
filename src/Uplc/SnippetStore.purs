module Uplc.SnippetStore
  ( deleteAndCommit
  , renameAndCommit
  ) where

import Control.Promise (Promise, toAffE)
import Effect (Effect)
import Effect.Aff (Aff)
import SpaKit.BrowserGit (BrowserRepo, WriteResult)

foreign import deleteAndCommitImpl :: BrowserRepo -> String -> String -> Effect (Promise WriteResult)

foreign import renameAndCommitImpl :: BrowserRepo -> String -> String -> String -> Effect (Promise WriteResult)

deleteAndCommit :: BrowserRepo -> String -> String -> Aff WriteResult
deleteAndCommit repo path message =
  toAffE (deleteAndCommitImpl repo path message)

renameAndCommit :: BrowserRepo -> String -> String -> String -> Aff WriteResult
renameAndCommit repo oldPath newPath message =
  toAffE (renameAndCommitImpl repo oldPath newPath message)
