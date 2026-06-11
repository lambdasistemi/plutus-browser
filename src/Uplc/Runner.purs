module Uplc.Runner
  ( runUplc
  ) where

import Prelude

import Effect.Aff (Aff)
import SpaKit.WasiRunner (WasmBytes, WasmCliResult, compileWasmModule, runWasmCli)

foreign import uplcWasmBytes :: WasmBytes

runUplc :: String -> Boolean -> Aff WasmCliResult
runUplc programText withBudget = do
  wasmModule <- compileWasmModule uplcWasmBytes
  runWasmCli wasmModule args programText
  where
  args =
    if withBudget then
      [ "uplc", "evaluate", "-c" ]
    else
      [ "uplc", "evaluate" ]
