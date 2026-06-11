module Uplc.App
  ( mkApp
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.CodeUnits as CodeUnits
import Data.String.Common as String
import Data.String.Pattern (Pattern(..), Replacement(..))
import Data.Traversable (traverse_)
import Effect (Effect)
import Effect.Aff (attempt, launchAff_)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import React.Basic (JSX, keyed)
import React.Basic.DOM as R
import React.Basic.DOM.Events as DOMEvents
import React.Basic.Events (SyntheticEvent, handler, handler_, merge, syntheticEvent)
import React.Basic.Hooks (component, useEffect, useEffectOnce, useState, (/\))
import React.Basic.Hooks as React
import SpaKit.BrowserGit (BrowserRepo, CommitInfo)
import SpaKit.BrowserGit as BrowserGit
import SpaKit.CodeMirror (codeEditor)
import SpaKit.MUI as M
import SpaKit.WasiRunner (WasmCliResult)
import Uplc.DialogControls as DialogControls
import Uplc.Examples (examples)
import Uplc.Format (formatUplc)
import Uplc.Runner (runUplc)
import Uplc.SnippetImport (fetchText, readFirstFileText)
import Uplc.SnippetStore as SnippetStore
import Uplc.Timer as Timer

defaultProgram :: String
defaultProgram =
  case Array.head examples of
    Just example -> example.program
    Nothing -> "(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])"

defaultSnippetName :: String
defaultSnippetName =
  case Array.head examples of
    Just example -> example.name
    Nothing -> "Example"

defaultAutoEvalDebounceMs :: Int
defaultAutoEvalDebounceMs = 350

defaultAutoCommitDebounceMs :: Int
defaultAutoCommitDebounceMs = 1500

drawerWidth :: Int
drawerWidth = 304

storageNamespace :: String
storageNamespace = "uplc-snippets-v1"

snippetPath :: String -> String
snippetPath name =
  name <> ".uplc"

snippetNameFromPath :: String -> Maybe String
snippetNameFromPath path =
  CodeUnits.stripSuffix (Pattern ".uplc") path

snippetNamesFromFiles :: Array String -> Array String
snippetNamesFromFiles =
  Array.sort <<< Array.mapMaybe snippetNameFromPath

normaliseName :: String -> String
normaliseName =
  String.trim

shortOid :: String -> String
shortOid =
  CodeUnits.take 7

shortTimestamp :: String -> String
shortTimestamp stamp =
  CodeUnits.take 19 (String.replace (Pattern "T") (Replacement " ") stamp)

type SnippetState =
  { repo :: BrowserRepo
  , snippets :: Array String
  , active :: String
  , content :: String
  , history :: Array CommitInfo
  }

type MenuPosition =
  { top :: Number
  , left :: Number
  }

loadInitialSnippets :: String -> Effect Unit -> (SnippetState -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit
loadInitialSnippets fallback setBusy applyState reportError =
  launchAff_ do
    loaded <- attempt do
      repo <- BrowserGit.initRepo storageNamespace
      files <- BrowserGit.listFiles repo
      let
        existingNames = snippetNamesFromFiles files
      names <-
        if Array.null existingNames then do
          if Array.null examples then do
            _ <- BrowserGit.writeAndCommit repo (snippetPath defaultSnippetName) fallback ("create " <> defaultSnippetName)
            pure [ defaultSnippetName ]
          else do
            traverse_
              ( \example ->
                  BrowserGit.writeAndCommit repo (snippetPath example.name) example.program ("create " <> example.name)
              )
              examples
            pure (map _.name examples)
        else
          pure existingNames
      let
        active = fromMaybe defaultSnippetName (Array.head names)
      content <- BrowserGit.readFile repo (snippetPath active)
      history <- BrowserGit.log repo (snippetPath active)
      pure { repo, snippets: names, active, content, history }
    liftEffect do
      setBusy
      case loaded of
        Left err -> reportError ("Snippet store failed: " <> message err)
        Right state -> applyState state

validateNewName :: Array String -> String -> Maybe String
validateNewName existing rawName
  | String.null rawName = Just "Name required"
  | CodeUnits.contains (Pattern "/") rawName = Just "Name cannot contain /"
  | CodeUnits.contains (Pattern "\\") rawName = Just "Name cannot contain \\"
  | Array.elem rawName existing = Just "Name already exists"
  | otherwise = Nothing

mkApp :: Effect (Unit -> JSX)
mkApp = component "UplcApp" \_ -> React.do
  program /\ setProgram <- useState defaultProgram
  persistedProgram /\ setPersistedProgram <- useState defaultProgram
  repo /\ setRepo <- useState (Nothing :: Maybe BrowserRepo)
  snippets /\ setSnippets <- useState ([] :: Array String)
  activeSnippet /\ setActiveSnippet <- useState (Nothing :: Maybe String)
  history /\ setHistory <- useState ([] :: Array CommitInfo)
  viewingVersion /\ setViewingVersion <- useState (Nothing :: Maybe CommitInfo)
  budget /\ setBudget <- useState false
  auto /\ setAuto <- useState true
  autoFormat /\ setAutoFormat <- useState false
  autoEvalDebounceMs /\ setAutoEvalDebounceMs <- useState defaultAutoEvalDebounceMs
  autoCommitDebounceMs /\ setAutoCommitDebounceMs <- useState defaultAutoCommitDebounceMs
  running /\ setRunning <- useState false
  storeBusy /\ setStoreBusy <- useState true
  saving /\ setSaving <- useState false
  status /\ setStatus <- useState "Ready"
  output /\ setOutput <- useState ""
  outputIsError /\ setOutputIsError <- useState false
  newOpen /\ setNewOpen <- useState false
  newName /\ setNewName <- useState ""
  newSource /\ setNewSource <- useState "empty"
  newCopySource /\ setNewCopySource <- useState defaultSnippetName
  newUrl /\ setNewUrl <- useState ""
  newFileText /\ setNewFileText <- useState (Nothing :: Maybe String)
  newFileLabel /\ setNewFileLabel <- useState ""
  newError /\ setNewError <- useState ""
  quickName /\ setQuickName <- useState ""
  quickError /\ setQuickError <- useState ""
  newFromMenu /\ setNewFromMenu <- useState (Nothing :: Maybe MenuPosition)
  renamingSnippet /\ setRenamingSnippet <- useState (Nothing :: Maybe String)
  renameName /\ setRenameName <- useState ""
  renameError /\ setRenameError <- useState ""

  let
    dirty =
      program /= persistedProgram && viewingVersion == Nothing

    activeName =
      fromMaybe "No snippet" activeSnippet

    savedLabel =
      case viewingVersion of
        Just _ -> "viewing history"
        Nothing ->
          if saving then
            "saving"
          else if dirty then
            "unsaved"
          else
            "saved"

    saveCurrent :: Effect Unit
    saveCurrent =
      case repo, activeSnippet, viewingVersion of
        Just currentRepo, Just name, Nothing ->
          when (program /= persistedProgram) do
            setSaving (const true)
            setStatus (const "Saving...")
            launchAff_ do
              result <- attempt do
                _ <- BrowserGit.writeAndCommit currentRepo (snippetPath name) program ("edit " <> name)
                BrowserGit.log currentRepo (snippetPath name)
              liftEffect do
                setSaving (const false)
                case result of
                  Left err -> setStatus (const ("Save failed: " <> message err))
                  Right nextHistory -> do
                    setPersistedProgram (const program)
                    setHistory (const nextHistory)
                    setStatus (const "Saved")
        _, _, _ -> pure unit

    loadSnippet :: String -> Effect Unit
    loadSnippet name =
      case repo, activeSnippet of
        Just currentRepo, Just currentName -> do
          setStoreBusy (const true)
          launchAff_ do
            result <- attempt do
              when (program /= persistedProgram && viewingVersion == Nothing) do
                _ <- BrowserGit.writeAndCommit currentRepo (snippetPath currentName) program ("edit " <> currentName)
                pure unit
              nextContent <- BrowserGit.readFile currentRepo (snippetPath name)
              nextHistory <- BrowserGit.log currentRepo (snippetPath name)
              pure { nextContent, nextHistory }
            liftEffect do
              setStoreBusy (const false)
              case result of
                Left err -> setStatus (const ("Snippet switch failed: " <> message err))
                Right loaded -> do
                  setActiveSnippet (const (Just name))
                  setProgram (const loaded.nextContent)
                  setPersistedProgram (const loaded.nextContent)
                  setHistory (const loaded.nextHistory)
                  setViewingVersion (const Nothing)
                  setStatus (const ("Loaded " <> name))
        _, _ -> pure unit

    viewHistory :: CommitInfo -> Effect Unit
    viewHistory commit =
      case repo, activeSnippet of
        Just currentRepo, Just name -> do
          setStoreBusy (const true)
          launchAff_ do
            result <- attempt (BrowserGit.checkout currentRepo (snippetPath name) commit.oid)
            liftEffect do
              setStoreBusy (const false)
              case result of
                Left err -> setStatus (const ("Version load failed: " <> message err))
                Right content -> do
                  setProgram (const content)
                  setViewingVersion (const (Just commit))
                  setStatus (const ("Viewing " <> shortOid commit.oid))
        _, _ -> pure unit

    restoreViewedVersion :: Effect Unit
    restoreViewedVersion =
      case repo, activeSnippet, viewingVersion of
        Just currentRepo, Just name, Just _ -> do
          setSaving (const true)
          setStatus (const "Restoring...")
          launchAff_ do
            result <- attempt do
              _ <- BrowserGit.writeAndCommit currentRepo (snippetPath name) program ("restore " <> name)
              BrowserGit.log currentRepo (snippetPath name)
            liftEffect do
              setSaving (const false)
              case result of
                Left err -> setStatus (const ("Restore failed: " <> message err))
                Right nextHistory -> do
                  setPersistedProgram (const program)
                  setHistory (const nextHistory)
                  setViewingVersion (const Nothing)
                  setStatus (const "Restored")
        _, _, _ -> pure unit

    closeNewDialog :: Effect Unit
    closeNewDialog = do
      setNewOpen (const false)
      setNewError (const "")

    resetNewDialog :: Effect Unit
    resetNewDialog = do
      setNewName (const "")
      setNewSource (const "empty")
      setNewCopySource (const (fromMaybe defaultSnippetName activeSnippet))
      setNewUrl (const "")
      setNewFileText (const Nothing)
      setNewFileLabel (const "")
      setNewError (const "")

    openNewDialogFrom :: String -> Effect Unit
    openNewDialogFrom source = do
      resetNewDialog
      setNewSource (const source)
      setNewOpen (const true)
      setNewFromMenu (const Nothing)

    openNewFromMenu :: { clientX :: Maybe Number, clientY :: Maybe Number } -> Effect Unit
    openNewFromMenu event = do
      setNewFromMenu
        ( const
            ( Just
                { left: fromMaybe 24.0 event.clientX
                , top: fromMaybe 80.0 event.clientY
                }
            )
        )

    closeNewFromMenu :: Effect Unit
    closeNewFromMenu =
      setNewFromMenu (const Nothing)

    changeNewSource :: String -> Effect Unit
    changeNewSource source = do
      setNewSource (const source)
      setNewError (const "")

    createQuickSnippet :: Effect Unit
    createQuickSnippet =
      case repo of
        Nothing -> setQuickError (const "Snippet store is not ready")
        Just currentRepo -> do
          let
            name = normaliseName quickName
          case validateNewName snippets name of
            Just err -> setQuickError (const err)
            Nothing -> do
              setStoreBusy (const true)
              setQuickError (const "")
              launchAff_ do
                result <- attempt do
                  _ <- BrowserGit.writeAndCommit currentRepo (snippetPath name) "" ("create " <> name)
                  names <- snippetNamesFromFiles <$> BrowserGit.listFiles currentRepo
                  nextHistory <- BrowserGit.log currentRepo (snippetPath name)
                  pure { names, nextHistory }
                liftEffect do
                  setStoreBusy (const false)
                  case result of
                    Left err -> setQuickError (const ("Create failed: " <> message err))
                    Right created -> do
                      setSnippets (const created.names)
                      setActiveSnippet (const (Just name))
                      setProgram (const "")
                      setPersistedProgram (const "")
                      setHistory (const created.nextHistory)
                      setViewingVersion (const Nothing)
                      setQuickName (const "")
                      setStatus (const ("Created " <> name))

    startRename :: String -> Effect Unit
    startRename name = do
      setRenamingSnippet (const (Just name))
      setRenameName (const name)
      setRenameError (const "")

    cancelRename :: Effect Unit
    cancelRename = do
      setRenamingSnippet (const Nothing)
      setRenameName (const "")
      setRenameError (const "")

    commitRename :: String -> Effect Unit
    commitRename oldName =
      case repo of
        Nothing -> setRenameError (const "Snippet store is not ready")
        Just currentRepo -> do
          let
            nextName = normaliseName renameName

            existing =
              Array.filter (_ /= oldName) snippets
          if nextName == oldName then
            cancelRename
          else
            case validateNewName existing nextName of
              Just err -> setRenameError (const err)
              Nothing -> do
                setStoreBusy (const true)
                setRenameError (const "")
                launchAff_ do
                  result <- attempt do
                    when (activeSnippet == Just oldName && dirty) do
                      _ <- BrowserGit.writeAndCommit currentRepo (snippetPath oldName) program ("edit " <> oldName)
                      pure unit
                    _ <- SnippetStore.renameAndCommit currentRepo (snippetPath oldName) (snippetPath nextName) ("rename " <> oldName <> " to " <> nextName)
                    names <- snippetNamesFromFiles <$> BrowserGit.listFiles currentRepo
                    let
                      nextActive =
                        if activeSnippet == Just oldName then
                          Just nextName
                        else
                          activeSnippet
                    nextContent <-
                      case nextActive of
                        Just active -> BrowserGit.readFile currentRepo (snippetPath active)
                        Nothing -> pure ""
                    nextHistory <-
                      case nextActive of
                        Just active -> BrowserGit.log currentRepo (snippetPath active)
                        Nothing -> pure []
                    pure { names, nextActive, nextContent, nextHistory }
                  liftEffect do
                    setStoreBusy (const false)
                    case result of
                      Left err -> setRenameError (const ("Rename failed: " <> message err))
                      Right renamed -> do
                        setSnippets (const renamed.names)
                        setActiveSnippet (const renamed.nextActive)
                        setProgram (const renamed.nextContent)
                        setPersistedProgram (const renamed.nextContent)
                        setHistory (const renamed.nextHistory)
                        setViewingVersion (const Nothing)
                        cancelRename
                        setStatus (const ("Renamed " <> oldName <> " to " <> nextName))

    deleteSnippet :: String -> Effect Unit
    deleteSnippet name =
      case repo of
        Nothing -> setStatus (const "Snippet store is not ready")
        Just currentRepo ->
          if Array.length snippets <= 1 then
            setStatus (const "Keep at least one snippet")
          else do
            setStoreBusy (const true)
            launchAff_ do
              result <- attempt do
                _ <- SnippetStore.deleteAndCommit currentRepo (snippetPath name) ("delete " <> name)
                names <- snippetNamesFromFiles <$> BrowserGit.listFiles currentRepo
                let
                  nextActive =
                    if activeSnippet == Just name then
                      Array.head names
                    else
                      case activeSnippet of
                        Just active -> Just active
                        Nothing -> Array.head names
                nextContent <-
                  case nextActive of
                    Just active -> BrowserGit.readFile currentRepo (snippetPath active)
                    Nothing -> pure ""
                nextHistory <-
                  case nextActive of
                    Just active -> BrowserGit.log currentRepo (snippetPath active)
                    Nothing -> pure []
                pure { names, nextActive, nextContent, nextHistory }
              liftEffect do
                setStoreBusy (const false)
                case result of
                  Left err -> setStatus (const ("Delete failed: " <> message err))
                  Right deleted -> do
                    setSnippets (const deleted.names)
                    setActiveSnippet (const deleted.nextActive)
                    setProgram (const deleted.nextContent)
                    setPersistedProgram (const deleted.nextContent)
                    setHistory (const deleted.nextHistory)
                    setViewingVersion (const Nothing)
                    when (renamingSnippet == Just name) cancelRename
                    setStatus (const ("Deleted " <> name))

    readSnippetFile :: SyntheticEvent -> Effect Unit
    readSnippetFile event = do
      setNewError (const "")
      launchAff_ do
        result <- attempt (readFirstFileText event)
        liftEffect case result of
          Left err -> setNewError (const ("File read failed: " <> message err))
          Right content -> do
            setNewFileText (const (Just content))
            setNewFileLabel (const "file loaded")

    createSnippet :: Effect Unit
    createSnippet =
      case repo of
        Nothing -> setNewError (const "Snippet store is not ready")
        Just currentRepo -> do
          let
            name = normaliseName newName
          case validateNewName snippets name of
            Just err -> setNewError (const err)
            Nothing ->
              if newSource == "file" && newFileText == Nothing then
                setNewError (const "Choose a file")
              else if newSource == "url" && String.null (String.trim newUrl) then
                setNewError (const "URL required")
              else do
                setStoreBusy (const true)
                setNewError (const "")
                launchAff_ do
                  result <- attempt do
                    content <-
                      case newSource of
                        "copy" -> BrowserGit.readFile currentRepo (snippetPath (fromMaybe activeName (Array.find (_ == newCopySource) snippets)))
                        "file" ->
                          case newFileText of
                            Just fileContent -> pure fileContent
                            Nothing -> pure ""
                        "url" -> fetchText newUrl
                        _ -> pure ""
                    _ <- BrowserGit.writeAndCommit currentRepo (snippetPath name) content ("create " <> name)
                    names <- snippetNamesFromFiles <$> BrowserGit.listFiles currentRepo
                    nextHistory <- BrowserGit.log currentRepo (snippetPath name)
                    pure { content, names, nextHistory }
                  liftEffect do
                    setStoreBusy (const false)
                    case result of
                      Left err -> setNewError (const ("Create failed: " <> message err))
                      Right created -> do
                        setSnippets (const created.names)
                        setActiveSnippet (const (Just name))
                        setProgram (const created.content)
                        setPersistedProgram (const created.content)
                        setHistory (const created.nextHistory)
                        setViewingVersion (const Nothing)
                        setStatus (const ("Created " <> name))
                        closeNewDialog

    evaluate :: Effect Unit
    evaluate = do
      setRunning (const true)
      setStatus (const "Evaluating...")
      launchAff_ do
        result <- attempt (runUplc program budget)
        liftEffect do
          setRunning (const false)
          case result of
            Left err -> do
              setOutput (const (message err))
              setOutputIsError (const true)
              setStatus (const "Browser execution failed")
            Right evalResult -> do
              setOutput (const (renderOutput evalResult))
              setOutputIsError (const (not evalResult.exitOk || not (String.null (String.trim evalResult.stderr))))
              setStatus
                ( const
                    ( if evalResult.exitOk then
                        "Evaluation complete"
                      else
                        "uplc failed"
                    )
                )

    formatProgram :: Effect Unit
    formatProgram =
      when (viewingVersion == Nothing) do
        setProgram (const (formatUplc program))

    onEditorBlur :: Effect Unit
    onEditorBlur =
      when autoFormat formatProgram

    outputColor =
      if outputIsError then
        "error.main"
      else
        "text.primary"

  useEffectOnce do
    loadInitialSnippets defaultProgram
      (setStoreBusy (const false))
      ( \state -> do
          setRepo (const (Just state.repo))
          setSnippets (const state.snippets)
          setActiveSnippet (const (Just state.active))
          setProgram (const state.content)
          setPersistedProgram (const state.content)
          setHistory (const state.history)
          setNewCopySource (const state.active)
          setStatus (const ("Snippet store: " <> BrowserGit.storageBackend))
      )
      (setStatus <<< const)
    pure (pure unit)

  useEffect (program <> show budget <> show auto <> show autoEvalDebounceMs) do
    if auto then do
      timeout <- Timer.setTimeout autoEvalDebounceMs evaluate
      pure (Timer.clearTimeout timeout)
    else
      pure (pure unit)

  useEffect (program <> activeName <> savedLabel <> show autoCommitDebounceMs) do
    if dirty then do
      timeout <- Timer.setTimeout autoCommitDebounceMs saveCurrent
      pure (Timer.clearTimeout timeout)
    else
      pure (pure unit)

  pure
    ( M.themeProvider { theme: M.defaultTheme }
        [ M.cssBaseline
        , M.box
            { sx:
                { height: "100vh"
                , display: "flex"
                , overflow: "hidden"
                , bgcolor: "background.default"
                , color: "text.primary"
                }
            }
            [ snippetDrawer
                { snippets
                , activeSnippet
                , savedLabel
                , history
                , viewingVersion
                , busy: storeBusy
                , quickName
                , quickError
                , newFromMenu
                , renamingSnippet
                , renameName
                , renameError
                , setQuickName
                , createQuickSnippet
                , openNewFromMenu
                , closeNewFromMenu
                , openNewDialogFrom
                , startRename
                , cancelRename
                , setRenameName
                , commitRename
                , deleteSnippet
                , loadSnippet
                , viewHistory
                , restoreViewedVersion
                }
            , M.box
                { sx:
                    { flexGrow: 1
                    , minWidth: 0
                    , display: "flex"
                    , flexDirection: "column"
                    , overflow: "hidden"
                    }
                }
                [ appBar activeName
                , M.container
                    { maxWidth: "xl"
                    , sx:
                        { flexGrow: 1
                        , minHeight: 0
                        , display: "flex"
                        , flexDirection: "column"
                        , py: 3
                        }
                    }
                    [ controls
                        running
                        budget
                        auto
                        autoFormat
                        autoEvalDebounceMs
                        autoCommitDebounceMs
                        setBudget
                        setAuto
                        setAutoFormat
                        setAutoEvalDebounceMs
                        setAutoCommitDebounceMs
                        evaluate
                        formatProgram
                        status
                        (viewingVersion /= Nothing)
                    , M.box
                        { component: "section"
                        , "aria-label": "UPLC evaluator"
                        , sx:
                            { flexGrow: 1
                            , minHeight: 0
                            , display: "grid"
                            , gridTemplateColumns: "minmax(0, 1fr) minmax(320px, 0.85fr)"
                            , gridTemplateRows: "minmax(0, 1fr)"
                            , gap: 2
                            , alignItems: "stretch"
                            }
                        }
                        [ editorCard activeName program setProgram onEditorBlur (viewingVersion /= Nothing)
                        , outputCard output outputColor
                        ]
                    ]
                ]
            , newSnippetDialog
                { open: newOpen
                , snippets
                , source: newSource
                , name: newName
                , copySource: newCopySource
                , url: newUrl
                , fileLabel: newFileLabel
                , error: newError
                , busy: storeBusy
                , setName: setNewName
                , setSource: changeNewSource
                , setCopySource: setNewCopySource
                , setUrl: setNewUrl
                , readSnippetFile
                , createSnippet
                , close: closeNewDialog
                }
            ]
        ]
    )

type SnippetDrawerProps =
  { snippets :: Array String
  , activeSnippet :: Maybe String
  , savedLabel :: String
  , history :: Array CommitInfo
  , viewingVersion :: Maybe CommitInfo
  , busy :: Boolean
  , quickName :: String
  , quickError :: String
  , newFromMenu :: Maybe MenuPosition
  , renamingSnippet :: Maybe String
  , renameName :: String
  , renameError :: String
  , setQuickName :: (String -> String) -> Effect Unit
  , createQuickSnippet :: Effect Unit
  , openNewFromMenu :: { clientX :: Maybe Number, clientY :: Maybe Number } -> Effect Unit
  , closeNewFromMenu :: Effect Unit
  , openNewDialogFrom :: String -> Effect Unit
  , startRename :: String -> Effect Unit
  , cancelRename :: Effect Unit
  , setRenameName :: (String -> String) -> Effect Unit
  , commitRename :: String -> Effect Unit
  , deleteSnippet :: String -> Effect Unit
  , loadSnippet :: String -> Effect Unit
  , viewHistory :: CommitInfo -> Effect Unit
  , restoreViewedVersion :: Effect Unit
  }

snippetDrawer :: SnippetDrawerProps -> JSX
snippetDrawer props =
  let
    historyMode =
      props.viewingVersion /= Nothing

    editDisabled =
      props.busy || historyMode

    snippetCount =
      Array.length props.snippets
  in
    M.drawer
      { variant: "permanent"
      , sx:
          { width: drawerWidth
          , flexShrink: 0
          , "& .MuiDrawer-paper":
              { width: drawerWidth
              , boxSizing: "border-box"
              , position: "relative"
              , height: "100vh"
              , overflow: "hidden"
              }
          }
      }
      [ M.box
          { sx:
              { height: "100%"
              , display: "flex"
              , flexDirection: "column"
              , borderRight: "1px solid"
              , borderColor: "divider"
              }
          }
          [ M.box { sx: { p: 1.5 } }
              [ M.stack { direction: "row", spacing: 1, alignItems: "center" }
                  [ M.textField
                      { label: "Quick add snippet"
                      , size: "small"
                      , value: props.quickName
                      , onChange: M.onValueChange (\next -> props.setQuickName (const next))
                      , onKeyDown:
                          handler DOMEvents.key \pressed ->
                            when (pressed == Just "Enter") props.createQuickSnippet
                      , disabled: props.busy
                      , sx: { flexGrow: 1 }
                      , inputProps: { "aria-label": "Quick add snippet" }
                      }
                  , M.tooltip { title: "Add snippet" }
                      [ M.iconButton
                          { "aria-label": "Add snippet"
                          , color: "primary"
                          , onClick: props.createQuickSnippet
                          , disabled: props.busy || String.null (String.trim props.quickName)
                          , sx: { width: 40, height: 40, flex: "0 0 auto" }
                          }
                          [ M.addIcon { fontSize: "small" } ]
                      ]
                  ]
              , M.button
                  { variant: "text"
                  , size: "small"
                  , onClick:
                      handler
                        ( merge
                            { clientX: DOMEvents.clientX
                            , clientY: DOMEvents.clientY
                            }
                        )
                        props.openNewFromMenu
                  , disabled: props.busy
                  , sx: { mt: 1, px: 0.5, justifyContent: "flex-start" }
                  }
                  [ R.text "new from..." ]
              , DialogControls.menu
                  { open: props.newFromMenu /= Nothing
                  , onClose: handler_ props.closeNewFromMenu
                  , anchorReference: "anchorPosition"
                  , anchorPosition: fromMaybe { top: 0.0, left: 0.0 } props.newFromMenu
                  , "MenuListProps": { "aria-label": "New snippet sources" }
                  }
                  [ DialogControls.menuItem { onClick: handler_ (props.openNewDialogFrom "copy") } [ R.text "Copy existing" ]
                  , DialogControls.menuItem { onClick: handler_ (props.openNewDialogFrom "file") } [ R.text "Local file" ]
                  , DialogControls.menuItem { onClick: handler_ (props.openNewDialogFrom "url") } [ R.text "URL" ]
                  ]
              , if String.null props.quickError then
                  mempty
                else
                  M.typography { variant: "caption", sx: { color: "error.main", display: "block", mt: 0.75 } } [ R.text props.quickError ]
              ]
          , M.divider {}
          , M.box { sx: { flex: "1 1 auto", minHeight: 0, overflow: "auto" } }
              [ M.list
                  { dense: true
                  , "aria-label": "Snippets"
                  , sx: { py: 0.5 }
                  }
                  ( map
                      ( \name ->
                          keyed ("snippet-" <> name)
                            (snippetListItem props editDisabled snippetCount name)
                      )
                      props.snippets
                  )
              ]
          , M.divider {}
          , M.box { sx: { p: 2, flex: "0 0 auto" } }
              ( [ M.typography { variant: "subtitle2", sx: { mb: 1, fontWeight: 700 } } [ R.text "History" ] ]
                  <> historyItems props.history props.viewingVersion props.busy props.viewHistory
                  <> restoreButton props.viewingVersion props.busy props.restoreViewedVersion
              )
          ]
      ]

snippetListItem :: SnippetDrawerProps -> Boolean -> Int -> String -> JSX
snippetListItem props editDisabled snippetCount name =
  case props.renamingSnippet of
    Just editing
      | editing == name -> renameSnippetRow props name editDisabled
    _ -> snippetRow props editDisabled snippetCount name

snippetRow :: SnippetDrawerProps -> Boolean -> Int -> String -> JSX
snippetRow props editDisabled snippetCount name =
  let
    active =
      props.activeSnippet == Just name
  in
    M.listItem { disablePadding: true }
      [ M.box
          { sx:
              { width: "100%"
              , display: "flex"
              , alignItems: "center"
              , "&:hover .snippet-actions, &:focus-within .snippet-actions":
                  { opacity: 1.0
                  }
              }
          }
          [ M.listItemButton
              { selected: active
              , onClick: props.loadSnippet name
              , disabled: props.busy
              , "data-testid": "snippet-row"
              , sx: { minWidth: 0, flexGrow: 1, py: 1 }
              }
              [ M.listItemText
                  { primary: name
                  , secondary:
                      if active then
                        props.savedLabel
                      else
                        ""
                  , primaryTypographyProps: { noWrap: true }
                  }
              ]
          , M.stack
              { className: "snippet-actions"
              , direction: "row"
              , spacing: 0.25
              , sx:
                  { flex: "0 0 auto"
                  , px: 0.5
                  , opacity:
                      if active then
                        1.0
                      else
                        0.0
                  , transition: "opacity 120ms ease"
                  }
              }
              [ M.tooltip { title: "Rename" }
                  [ M.iconButton
                      { size: "small"
                      , "aria-label": "Rename " <> name
                      , onClick: props.startRename name
                      , disabled: editDisabled
                      , sx: { width: 30, height: 30 }
                      }
                      [ M.editIcon { fontSize: "small" } ]
                  ]
              , M.tooltip { title: "Delete" }
                  [ M.iconButton
                      { size: "small"
                      , "aria-label": "Delete " <> name
                      , onClick: props.deleteSnippet name
                      , disabled: editDisabled || snippetCount <= 1
                      , sx: { width: 30, height: 30 }
                      }
                      [ M.deleteIcon { fontSize: "small" } ]
                  ]
              ]
          ]
      ]

renameSnippetRow :: SnippetDrawerProps -> String -> Boolean -> JSX
renameSnippetRow props name editDisabled =
  M.listItem { disablePadding: true }
    [ M.box { sx: { width: "100%", p: 1 } }
        [ M.stack { direction: "row", spacing: 0.5, alignItems: "center" }
            [ M.textField
                { label: "Rename snippet"
                , size: "small"
                , value: props.renameName
                , onChange: M.onValueChange (\next -> props.setRenameName (const next))
                , onKeyDown:
                    handler DOMEvents.key \pressed ->
                      case pressed of
                        Just "Enter" -> props.commitRename name
                        Just "Escape" -> props.cancelRename
                        _ -> pure unit
                , autoFocus: true
                , disabled: editDisabled
                , sx: { flexGrow: 1 }
                , inputProps: { "aria-label": "Rename snippet" }
                }
            , M.tooltip { title: "Save" }
                [ M.iconButton
                    { size: "small"
                    , "aria-label": "Save rename"
                    , onClick: props.commitRename name
                    , disabled: editDisabled
                    }
                    [ M.saveIcon { fontSize: "small" } ]
                ]
            , M.tooltip { title: "Cancel" }
                [ M.iconButton
                    { size: "small"
                    , "aria-label": "Cancel rename"
                    , onClick: props.cancelRename
                    , disabled: props.busy
                    }
                    [ M.closeIcon { fontSize: "small" } ]
                ]
            ]
        , if String.null props.renameError then
            mempty
          else
            M.typography { variant: "caption", sx: { color: "error.main", display: "block", mt: 0.5 } } [ R.text props.renameError ]
        ]
    ]

historyItems :: Array CommitInfo -> Maybe CommitInfo -> Boolean -> (CommitInfo -> Effect Unit) -> Array JSX
historyItems history viewingVersion busy viewHistory =
  if Array.null history then
    [ M.typography { variant: "body2", sx: { color: "text.secondary" } } [ R.text "No versions" ] ]
  else
    [ M.list
        { dense: true
        , "aria-label": "Snippet history"
        , sx: { maxHeight: 220, overflow: "auto", border: "1px solid", borderColor: "divider", borderRadius: 1 }
        }
        ( map
            ( \commit ->
                keyed ("history-" <> commit.oid)
                  ( M.listItem { disablePadding: true }
                      [ M.listItemButton
                          { selected: case viewingVersion of
                              Just viewed -> viewed.oid == commit.oid
                              Nothing -> false
                          , onClick: viewHistory commit
                          , disabled: busy
                          }
                          [ M.listItemText
                              { primary: shortTimestamp commit.timestamp
                              , secondary: commit.message <> " " <> shortOid commit.oid
                              }
                          ]
                      ]
                  )
            )
            history
        )
    ]

restoreButton :: Maybe CommitInfo -> Boolean -> Effect Unit -> Array JSX
restoreButton viewingVersion busy restoreViewedVersion =
  case viewingVersion of
    Nothing -> []
    Just _ ->
      [ M.button
          { variant: "outlined"
          , fullWidth: true
          , sx: { mt: 1 }
          , onClick: restoreViewedVersion
          , disabled: busy
          }
          [ M.undoIcon { fontSize: "small" }, R.text "Restore version" ]
      ]

type NewSnippetDialogProps =
  { open :: Boolean
  , snippets :: Array String
  , source :: String
  , name :: String
  , copySource :: String
  , url :: String
  , fileLabel :: String
  , error :: String
  , busy :: Boolean
  , setName :: (String -> String) -> Effect Unit
  , setSource :: String -> Effect Unit
  , setCopySource :: (String -> String) -> Effect Unit
  , setUrl :: (String -> String) -> Effect Unit
  , readSnippetFile :: SyntheticEvent -> Effect Unit
  , createSnippet :: Effect Unit
  , close :: Effect Unit
  }

newSnippetDialog :: NewSnippetDialogProps -> JSX
newSnippetDialog props =
  M.dialog
    { open: props.open
    , onClose: handler_ props.close
    , fullWidth: true
    , maxWidth: "md"
    , "PaperProps": { sx: { width: "min(720px, calc(100vw - 32px))" } }
    }
    [ M.dialogTitle {} [ R.text "New snippet" ]
    , M.dialogContent
        { dividers: true
        , sx: { display: "flex", flexDirection: "column", gap: 2.5, pt: "20px !important", pb: 3 }
        }
        [ M.textField
            { label: "Snippet name"
            , value: props.name
            , onChange: M.onValueChange (\next -> props.setName (const next))
            , autoFocus: true
            , fullWidth: true
            }
        , DialogControls.selectField
            { id: "new-snippet-source"
            , label: "Snippet source"
            , value: props.source
            , onChange:
                handler DOMEvents.targetValue \next ->
                  case next of
                    Just value -> props.setSource value
                    Nothing -> pure unit
            }
            [ DialogControls.menuItem { value: "empty" } [ R.text "Empty" ]
            , DialogControls.menuItem { value: "copy" } [ R.text "Copy of snippet" ]
            , DialogControls.menuItem { value: "file" } [ R.text "From local file" ]
            , DialogControls.menuItem { value: "url" } [ R.text "From URL" ]
            ]
        , case props.source of
            "copy" ->
              DialogControls.selectField
                { id: "new-snippet-copy-source"
                , label: "Copy source"
                , value: props.copySource
                , onChange:
                    handler DOMEvents.targetValue \next ->
                      case next of
                        Just value -> props.setCopySource (const value)
                        Nothing -> pure unit
                }
                ( map
                    (\name -> DialogControls.menuItem { value: name } [ R.text name ])
                    props.snippets
                )
            "file" ->
              M.stack { spacing: 1.25, alignItems: "flex-start" }
                [ M.button
                    { variant: "outlined"
                    , component: "label"
                    , disabled: props.busy
                    }
                    [ M.addIcon { fontSize: "small" }
                    , R.text "Choose local file"
                    , R.input
                        { title: "Snippet file"
                        , type: "file"
                        , accept: ".uplc,text/plain"
                        , hidden: true
                        , onChange: handler syntheticEvent props.readSnippetFile
                        }
                    ]
                , M.typography { variant: "body2", sx: { color: "text.secondary" } }
                    [ R.text
                        ( if String.null props.fileLabel then
                            "No file selected"
                          else
                            props.fileLabel
                        )
                    ]
                ]
            "url" ->
              M.textField
                { label: "Snippet URL"
                , value: props.url
                , onChange: M.onValueChange (\next -> props.setUrl (const next))
                , fullWidth: true
                }
            _ -> mempty
        , if String.null props.error then
            mempty
          else
            M.alert { severity: "error" } [ R.text props.error ]
        ]
    , M.dialogActions {}
        [ M.button { onClick: props.close, disabled: props.busy } [ R.text "Cancel" ]
        , M.button { variant: "contained", onClick: props.createSnippet, disabled: props.busy } [ R.text "Create" ]
        ]
    ]

appBar :: String -> JSX
appBar activeName =
  M.appBar { position: "static", elevation: 0 }
    [ M.toolbar { sx: { gap: 2 } }
        [ M.typography
            { variant: "h6"
            , component: "h1"
            , sx: { flexGrow: 1, fontWeight: 700 }
            }
            [ R.text "Plutus Browser" ]
        , M.chip { label: activeName, color: "secondary", variant: "outlined" }
        , M.link
            { href: "https://github.com/lambdasistemi/plutus-browser"
            , target: "_blank"
            , rel: "noopener"
            , color: "inherit"
            , underline: "hover"
            }
            [ R.text "repo" ]
        , M.link
            { href: "https://github.com/lambdasistemi/plutus/releases/tag/1.65.0.0-wasm32.1"
            , target: "_blank"
            , rel: "noopener"
            , color: "inherit"
            , underline: "hover"
            }
            [ R.text "evaluator" ]
        ]
    ]

controls
  :: Boolean
  -> Boolean
  -> Boolean
  -> Boolean
  -> Int
  -> Int
  -> ((Boolean -> Boolean) -> Effect Unit)
  -> ((Boolean -> Boolean) -> Effect Unit)
  -> ((Boolean -> Boolean) -> Effect Unit)
  -> ((Int -> Int) -> Effect Unit)
  -> ((Int -> Int) -> Effect Unit)
  -> Effect Unit
  -> Effect Unit
  -> String
  -> Boolean
  -> JSX
controls running budget auto autoFormat autoEvalDebounceMs autoCommitDebounceMs setBudget setAuto setAutoFormat setAutoEvalDebounceMs setAutoCommitDebounceMs evaluate formatProgram status historyMode =
  M.stack
    { direction: "row"
    , spacing: 2
    , alignItems: "center"
    , sx: { mb: 2, flexWrap: "wrap" }
    }
    [ M.button
        { variant: "outlined"
        , onClick: formatProgram
        , disabled: running || historyMode
        }
        [ M.editIcon { fontSize: "small" }, R.text "Format" ]
    , toggle "auto-format" autoFormat (\checked -> setAutoFormat (const checked)) "auto format"
    , toggle "budget" budget (\checked -> setBudget (const checked)) "show budget (-c)"
    , toggle "auto" auto (\checked -> setAuto (const checked)) "auto evaluate"
    , debounceField "Eval delay" "auto evaluate debounce milliseconds" autoEvalDebounceMs setAutoEvalDebounceMs
    , debounceField "Commit delay" "auto commit debounce milliseconds" autoCommitDebounceMs setAutoCommitDebounceMs
    , M.button
        { variant: "contained"
        , onClick: evaluate
        , disabled: running
        }
        [ M.syncIcon { fontSize: "small" }, R.text "Evaluate" ]
    , M.typography
        { id: "status"
        , variant: "body2"
        , sx: { color: "text.secondary", minHeight: "24px" }
        }
        [ R.text status ]
    ]

debounceField :: String -> String -> Int -> ((Int -> Int) -> Effect Unit) -> JSX
debounceField label ariaLabel value setValue =
  M.textField
    { label
    , type: "number"
    , size: "small"
    , value: show value
    , onChange: M.onValueChange (setPositiveMs setValue)
    , inputProps: { min: 1, step: 50, "aria-label": ariaLabel }
    , sx: { width: 132 }
    }

setPositiveMs :: ((Int -> Int) -> Effect Unit) -> String -> Effect Unit
setPositiveMs setValue raw =
  case Int.fromString (String.trim raw) of
    Just next
      | next > 0 -> setValue (const next)
    _ -> pure unit

toggle :: String -> Boolean -> (Boolean -> Effect Unit) -> String -> JSX
toggle label checked onToggle ariaLabel =
  M.stack { direction: "row", spacing: 1, alignItems: "center" }
    [ M.typography { variant: "body2" } [ R.text label ]
    , M.switch
        { checked
        , onChange: M.onCheckedChange onToggle
        , inputProps: { "aria-label": ariaLabel }
        }
    ]

editorCard :: String -> String -> ((String -> String) -> Effect Unit) -> Effect Unit -> Boolean -> JSX
editorCard activeName program setProgram onEditorBlur historyMode =
  M.card
    { variant: "outlined"
    , sx: { height: "100%", display: "flex", flexDirection: "column" }
    }
    [ M.cardHeader { title: "UPLC program", subheader: activeName }
    , M.cardContent
        { sx: { p: 0, flexGrow: 1, minHeight: 0, display: "flex", flexDirection: "column" } }
        [ M.box
            { onBlur: handler_ onEditorBlur
            , sx: { flexGrow: 1, minHeight: 0, height: "100%", width: "100%", opacity: if historyMode then 0.92 else 1.0 }
            }
            [ codeEditor
                { value: program
                , onChange:
                    \next ->
                      unless historyMode do
                        setProgram (const next)
                , ariaLabel: "UPLC program"
                }
            ]
        ]
    ]

outputCard :: String -> String -> JSX
outputCard output outputColor =
  M.card
    { variant: "outlined"
    , sx: { height: "100%", display: "flex", flexDirection: "column" }
    }
    [ M.cardHeader { title: "Output" }
    , M.cardContent
        { sx: { p: 0, flexGrow: 1, minHeight: 0, display: "flex", flexDirection: "column" } }
        [ M.typography
            { id: "output"
            , component: "pre"
            , "aria-live": "polite"
            , sx:
                { flexGrow: 1
                , minHeight: 0
                , m: 0
                , p: 2
                , overflow: "auto"
                , whiteSpace: "pre-wrap"
                , fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, Liberation Mono, monospace"
                , fontSize: "0.94rem"
                , lineHeight: 1.5
                , color: outputColor
                , bgcolor: "#fbfcfe"
                }
            }
            [ R.text output ]
        ]
    ]

renderOutput :: WasmCliResult -> String
renderOutput result =
  let
    stdout =
      String.trim result.stdout

    stderr =
      String.trim result.stderr

    sections =
      (if String.null stdout then [] else [ stdout ])
        <> (if String.null stderr then [] else [ "stderr:\n" <> stderr ])
  in
    if Array.null sections then
      if result.exitOk then "(no output)" else "uplc exited without output"
    else
      String.joinWith "\n\n" sections
