module Uplc.Examples
  ( examples
  ) where

type Example =
  { name :: String
  , program :: String
  }

examples :: Array Example
examples =
  [ { name: "01-add-integers", program: "(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])\n" }
  , { name: "02-multiply-integers", program: "(program 1.0.0 [ [ (builtin multiplyInteger) (con integer 6) ] (con integer 7) ])\n" }
  , { name: "03-divide-integers", program: "(program 1.0.0 [ [ (builtin divideInteger) (con integer 84) ] (con integer 2) ])\n" }
  , { name: "04-nested-arithmetic", program: "(program 1.0.0 [ [ (builtin addInteger) [ [ (builtin multiplyInteger) (con integer 6) ] (con integer 7) ] ] [ [ (builtin subtractInteger) (con integer 10) ] (con integer 10) ] ])\n" }
  , { name: "05-equals-integer", program: "(program 1.0.0 [ [ (builtin equalsInteger) (con integer 5) ] (con integer 5) ])\n" }
  , { name: "06-if-then-else", program: "(program 1.0.0 [ [ [ (force (builtin ifThenElse)) (con bool True) ] (con integer 111) ] (con integer 222) ])\n" }
  , { name: "07-lambda-increment", program: "(program 1.0.0 [ (lam x [ [ (builtin addInteger) x ] (con integer 1) ]) (con integer 41) ])\n" }
  , { name: "08-append-bytestring", program: "(program 1.0.0 [ [ (builtin appendByteString) (con bytestring #cafe) ] (con bytestring #babe) ])\n" }
  , { name: "09-length-bytestring", program: "(program 1.0.0 [ (builtin lengthOfByteString) (con bytestring #deadbeef) ])\n" }
  , { name: "10-cons-bytestring", program: "(program 1.0.0 [ [ (builtin consByteString) (con integer 104) ] (con bytestring #656c6c6f) ])\n" }
  , { name: "11-equals-string", program: "(program 1.0.0 [ [ (builtin equalsString) (con string \"hello\") ] (con string \"hello\") ])\n" }
  , { name: "12-sha2-256-empty", program: "(program 1.0.0 [ (builtin sha2_256) (con bytestring #) ])\n" }
  , { name: "13-trace", program: "(program 1.0.0 [ [ (force (builtin trace)) (con string \"hello from uplc\") ] (con integer 42) ])\n" }
  , { name: "14-error-fails", program: "(program 1.0.0 (error))\n" }
  , { name: "15-factorial-recursion", program: "(program 1.0.0 [ [ (lam f [ (lam x [ f (lam v [ [ x x ] v ]) ]) (lam x [ f (lam v [ [ x x ] v ]) ]) ]) (lam rec (lam n (force [ [ [ (force (builtin ifThenElse)) [ [ (builtin equalsInteger) n ] (con integer 0) ] ] (delay (con integer 1)) ] (delay [ [ (builtin multiplyInteger) n ] [ rec [ [ (builtin subtractInteger) n ] (con integer 1) ] ] ]) ]))) ] (con integer 5) ])\n" }
  , { name: "16-fibonacci-recursion", program: "(program 1.0.0 [ [ (lam f [ (lam x [ f (lam v [ [ x x ] v ]) ]) (lam x [ f (lam v [ [ x x ] v ]) ]) ]) (lam rec (lam n (force [ [ [ (force (builtin ifThenElse)) [ [ (builtin lessThanInteger) n ] (con integer 2) ] ] (delay n) ] (delay [ [ (builtin addInteger) [ rec [ [ (builtin subtractInteger) n ] (con integer 1) ] ] ] [ rec [ [ (builtin subtractInteger) n ] (con integer 2) ] ] ]) ]))) ] (con integer 10) ])\n" }
  , { name: "17-head-of-list", program: "(program 1.0.0 [ (force (builtin headList)) (con (list integer) [11, 22, 33]) ])\n" }
  , { name: "18-constr-case", program: "(program 1.1.0 (case (constr 1) (con integer 10) (con integer 20)))\n" }
  , { name: "19-integer-to-bytestring", program: "(program 1.0.0 [ [ [ (builtin integerToByteString) (con bool True) ] (con integer 0) ] (con integer 4299) ])\n" }
  , { name: "20-bytestring-to-integer", program: "(program 1.0.0 [ [ (builtin byteStringToInteger) (con bool True) ] (con bytestring #10cb) ])\n" }
  , { name: "21-shift-bytestring", program: "(program 1.0.0 [ [ (builtin shiftByteString) (con bytestring #0f) ] (con integer 4) ])\n" }
  , { name: "22-and-bytestring", program: "(program 1.0.0 [ [ [ (builtin andByteString) (con bool False) ] (con bytestring #ff0f) ] (con bytestring #0ff0) ])\n" }
  ]
