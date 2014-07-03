--
-- Data vault for metrics
--
-- Copyright © 2013-2014 Anchor Systems, Pty Ltd and Others
--
-- The code in this file, and the program it is a part of, is
-- made available to you by its authors as open source software:
-- you can redistribute it and/or modify it under the terms of
-- the 3-clause BSD licence.
--

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (throw)
import Data.HashMap.Strict (fromList)
import Test.Hspec
import Test.Hspec.QuickCheck
import Vaultaire.Types

main :: IO ()
main = hspec suite

suite :: Spec
suite = do
    describe "WireFormat identity tests" $ do
        prop "Daymap" (wireId :: DayMap -> Bool)
        prop "ContentsOperation" (wireId :: ContentsOperation -> Bool)
        prop "ContentsResponse" (wireId :: ContentsResponse -> Bool)
        prop "WriteResult" (wireId :: WriteResult -> Bool)
        prop "ReadStream" (wireId :: ReadStream -> Bool)
        prop "Address" (wireId :: Address -> Bool)
        prop "SourceDict" (wireId :: SourceDict -> Bool)
        prop "ReadRequest" (wireId :: ReadRequest -> Bool)
        prop "PassThrough" (wireId :: PassThrough -> Bool)

    describe "source dict wire format" $
        it "parses string to map" $ do
            let hm =  fromList [ ("metric","cpu")
                            , ("server","example")]
            let expected = either error id $ makeSourceDict hm
            let wire = either throw id $ fromWire "server:example,metric:cpu"
            wire `shouldBe` expected

    describe "Contents list bypass" $ do
        prop "has same wire format for all" contentsListBypassId
        it "has same wire format for known case" $ do
            let al = [("metric","cpu"), ("server","www.example.com")]
            let (Right source_dict) = makeSourceDict $ fromList al
            let encoded = toWire source_dict
            let expected = "\x02\
                           \\x01\x00\x00\x00\x00\x00\x00\x00\
                           \\x22\x00\x00\x00\x00\x00\x00\x00\
                           \metric:cpu,server:www.example.com,"

            toWire (ContentsListEntry 1 source_dict) `shouldBe` expected
            toWire (ContentsListBypass 1 encoded) `shouldBe` expected

contentsListBypassId :: SourceDict -> Address -> Bool
contentsListBypassId dict addr = toWire entry == toWire bypass
  where
    entry = ContentsListEntry addr dict
    bypass = ContentsListBypass addr (toWire dict)

wireId :: (Eq w, WireFormat w) => w -> Bool
wireId op = id' op == op
  where
    id' = fromRight . fromWire . toWire
    fromRight = either (error . show) id

