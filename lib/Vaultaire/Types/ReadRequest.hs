--
-- Copyright © 2013-2014 Anchor Systems, Pty Ltd and Others
--
-- The code in this file, and the program it is a part of, is
-- made available to you by its authors as open source software:
-- you can redistribute it and/or modify it under the terms of
-- the 3-clause BSD licence.
--

{-# LANGUAGE OverloadedStrings #-}

module Vaultaire.Types.ReadRequest
(
    ReadRequest(..),
) where

import Control.Applicative
import Control.Exception
import Data.ByteString (ByteString)
import qualified Data.ByteString as S
import Data.Packer (getBytes, getWord64LE, getWord8, putBytes, putWord64LE,
                    putWord8, runPacking, tryUnpacking)
import Data.Word (Word8)
import Test.QuickCheck
import Vaultaire.Classes.WireFormat
import Vaultaire.Types.Address
import Vaultaire.Types.TimeStamp

data ReadRequest = SimpleReadRequest Address TimeStamp TimeStamp
                 | ExtendedReadRequest Address TimeStamp TimeStamp
  deriving (Eq, Show)

instance WireFormat ReadRequest where
    toWire (SimpleReadRequest addr start end) =
        packWithHeaderByte 0 addr start end
    toWire (ExtendedReadRequest addr start end) =
        packWithHeaderByte 1 addr start end

    fromWire bs
        | S.length bs /= 25 = Left . SomeException $ userError "expected 25 bytes"
        | otherwise = flip tryUnpacking bs $ do
            header <- getWord8
            addr_bytes <- getBytes 8
            addr <- either (fail . show) return $ fromWire addr_bytes
            start <- TimeStamp <$> getWord64LE
            end <- TimeStamp <$> getWord64LE
            case header of
                0 -> return $ SimpleReadRequest addr start end
                1 -> return $ ExtendedReadRequest addr start end
                _ -> fail "invalid header byte"

packWithHeaderByte :: Word8 -> Address -> TimeStamp -> TimeStamp -> ByteString
packWithHeaderByte header addr start end =
    let addr_bytes = toWire addr
    in runPacking 25 $ do
        putWord8 header
        putBytes addr_bytes
        putWord64LE (unTimeStamp start)
        putWord64LE (unTimeStamp end)

instance Arbitrary ReadRequest where
    arbitrary =
        oneof [ SimpleReadRequest <$> arbitrary <*> arbitrary <*> arbitrary
              , ExtendedReadRequest <$> arbitrary <*> arbitrary <*> arbitrary ]
